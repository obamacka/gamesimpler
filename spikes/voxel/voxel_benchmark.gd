# Voxel spike benchmark (plan P0.8 b, d, j, k; P0.9). Run windowed on each target machine with
# ci/run_benchmark.sh (Linux, macOS) or ci/run_benchmark.ps1 (Windows), or directly:
#   godot --path . --resolution 1920x1080 res://spikes/voxel/voxel_benchmark.tscn -- --duration=60 --tier=min --machine="i7-3770 / GTX 1070"
# --tier=min checks the 30 fps target, --tier=rec the 60 fps target (spec D25, D26).
# Writes user://voxel_benchmark_<time>.json and prints a summary plus a markdown table row.
# A capsule "player" runs across generated hills at run speed (5 m/s) with the camera behind it,
# digs one voxel ahead every 0.25 s, and every 3 s digs a 3x3 pit under itself to time
# edit-to-collision (physics frames until the body is no longer on the floor).
extends Node3D

const RUN_SPEED := 5.0
const GRAVITY := 24.0
const VIEW_DISTANCE := 96
const DIG_INTERVAL := 0.25
const PIT_INTERVAL := 3.0
const MESH_WAIT_TIMEOUT := 30.0

var duration := 60.0
var tier := "min"
var machine := "unnamed"

var _terrain: VoxelTerrain
var _vt: VoxelTool
var _body: CharacterBody3D
var _phase := "warmup"
var _elapsed := 0.0
var _warmup := 0.0
var _frame_ms: PackedFloat32Array = []
var _dig_timer := 0.0
var _pit_timer := 0.0
var _pit_pending := false
var _pit_frames := 0
var _pit_t0 := 0
var _pit_samples_frames: Array[int] = []
var _pit_samples_ms: Array[float] = []
var _edits := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--duration="):
			duration = float(arg.get_slice("=", 1))
		elif arg.begins_with("--tier="):
			tier = arg.get_slice("=", 1)
		elif arg.begins_with("--machine="):
			machine = arg.get_slice("=", 1)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_build_world()


func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var lib := VoxelBlockyLibrary.new()
	lib.add_model(VoxelBlockyModelEmpty.new())
	for color in [Color(0.35, 0.7, 0.3), Color(0.5, 0.35, 0.2), Color(0.5, 0.5, 0.55), Color(0.85, 0.6, 0.3)]:
		var cube := VoxelBlockyModelCube.new()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		cube.set_material_override(0, mat)
		lib.add_model(cube)
	lib.bake()
	var mesher := VoxelMesherBlocky.new()
	mesher.library = lib

	_terrain = VoxelTerrain.new()
	_terrain.mesher = mesher
	_terrain.generator = preload("res://spikes/voxel/benchmark_generator.gd").new()
	_terrain.max_view_distance = VIEW_DISTANCE
	_terrain.generate_collisions = true
	add_child(_terrain)
	_vt = _terrain.get_voxel_tool()
	_vt.channel = VoxelBuffer.CHANNEL_TYPE

	_body = CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 2.1
	cap.radius = 0.35
	shape.shape = cap
	_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cap_mesh := CapsuleMesh.new()
	cap_mesh.height = 2.1
	cap_mesh.radius = 0.35
	mesh.mesh = cap_mesh
	_body.add_child(mesh)
	_body.add_child(VoxelViewer.new())
	var cam := Camera3D.new()
	cam.position = Vector3(-4.0, 2.5, 0.0)
	cam.rotation_degrees = Vector3(-15, -90, 0)
	_body.add_child(cam)
	_body.position = Vector3(0.5, 40.0, 0.5)
	add_child(_body)


func _process(delta: float) -> void:
	match _phase:
		"warmup":
			_warmup += delta
			var area := AABB(Vector3(-16, 0, -16), Vector3(32, 40, 32))
			if (_terrain.is_area_meshed(area) and _body.is_on_floor()) or _warmup > MESH_WAIT_TIMEOUT:
				print("[voxel_benchmark] warmup %.1f s (meshed=%s)" % [_warmup, _terrain.is_area_meshed(area)])
				_phase = "run"
		"run":
			_frame_ms.append(delta * 1000.0)
			_elapsed += delta
			if _elapsed >= duration:
				_finish()


func _physics_process(delta: float) -> void:
	if not _body.is_on_floor():
		_body.velocity.y -= GRAVITY * delta
	else:
		_body.velocity.y = 0.0
	if _phase == "run":
		_body.velocity.x = RUN_SPEED
		_dig_timer += delta
		_pit_timer += delta
		if _dig_timer >= DIG_INTERVAL:
			_dig_timer = 0.0
			var ahead := Vector3i(floori(_body.position.x) + 3, floori(_body.position.y), floori(_body.position.z))
			_vt.set_voxel(ahead, 0)
			_edits += 1
		if _pit_pending:
			_pit_frames += 1
			if not _body.is_on_floor() or _pit_frames >= 120:
				_pit_samples_frames.append(_pit_frames)
				_pit_samples_ms.append((Time.get_ticks_usec() - _pit_t0) / 1000.0)
				_pit_pending = false
		elif _pit_timer >= PIT_INTERVAL and _body.is_on_floor():
			_pit_timer = 0.0
			var c := Vector3i(floori(_body.position.x), floori(_body.position.y - 1.6), floori(_body.position.z))
			for x in range(-1, 2):
				for z in range(-1, 2):
					_vt.set_voxel(c + Vector3i(x, 0, z), 0)
					_edits += 1
			_pit_pending = true
			_pit_frames = 0
			_pit_t0 = Time.get_ticks_usec()
	else:
		_body.velocity.x = 0.0
	_body.move_and_slide()


func _finish() -> void:
	_phase = "done"
	var sorted := _frame_ms.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	for v in sorted:
		total += v
	var over_33 := 0
	var over_16 := 0
	for v in sorted:
		if v > 33.3:
			over_33 += 1
		if v > 16.7:
			over_16 += 1
	var p99 := sorted[min(n - 1, int(n * 0.99))] if n > 0 else 0.0
	var pit_max_ms := 0.0
	var pit_max_frames := 0
	for i in _pit_samples_ms.size():
		pit_max_ms = max(pit_max_ms, _pit_samples_ms[i])
		pit_max_frames = max(pit_max_frames, _pit_samples_frames[i])
	var report := {
		"timestamp": Time.get_datetime_string_from_system(),
		"cpu": OS.get_processor_name(),
		"cpu_threads": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"display_server": DisplayServer.get_name(),
		"window_size": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"view_distance": VIEW_DISTANCE,
		"duration_s": _elapsed,
		"frames": n,
		"avg_fps": (n / (total / 1000.0)) if total > 0.0 else 0.0,
		"avg_frame_ms": (total / n) if n > 0 else 0.0,
		"p99_frame_ms": p99,
		"max_frame_ms": sorted[n - 1] if n > 0 else 0.0,
		"frames_over_33ms": over_33,
		"frames_over_16_7ms": over_16,
		"voxel_edits": _edits,
		"edit_to_collision_samples": _pit_samples_ms.size(),
		"edit_to_collision_max_ms": pit_max_ms,
		"edit_to_collision_max_frames": pit_max_frames,
	}
	var target_fps := 60.0 if tier == "rec" else 30.0
	var budget_ms := 1000.0 / target_fps
	var over_budget := over_16 if tier == "rec" else over_33
	var avg_fps: float = report["avg_fps"]
	var reasons: Array[String] = []
	if avg_fps < target_fps:
		reasons.append("avg fps below %d" % int(target_fps))
	if n > 0 and float(over_budget) / n > 0.01:
		reasons.append("more than 1%% of frames over %.1f ms" % budget_ms)
	if pit_max_ms > 100.0:
		reasons.append("edit-to-collision over 100 ms")
	if OS.get_name() == "macOS" and report["rendering_driver"] != "metal":
		reasons.append("not using Metal")
	report["tier"] = tier
	report["machine"] = machine
	report["pass"] = reasons.is_empty()
	report["fail_reasons"] = reasons
	var path := "user://voxel_benchmark_%s.json" % Time.get_datetime_string_from_system().replace(":", "-")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("[voxel_benchmark] %s" % JSON.stringify(report))
	print("[voxel_benchmark] report written to %s" % ProjectSettings.globalize_path(path))
	# Same columns as the table in _docs/reports/voxel_spike.md
	print("[voxel_benchmark_row] | %s (%s, %s) | %.1f | %.1f | %.1f | %d | %.1f | %s | %s |" % [
		machine, report["cpu"], report["gpu"], avg_fps, p99, report["max_frame_ms"], over_33,
		pit_max_ms, report["rendering_driver"],
		("PASS (%s)" % tier) if reasons.is_empty() else ("FAIL (%s): %s" % [tier, ", ".join(reasons)])])
	get_tree().quit(0)
