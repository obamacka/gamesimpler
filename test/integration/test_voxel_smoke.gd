# Phase 0 voxel spike, real-terrain smoke suite (spec 8.2 item 11, plan P0.8).
# Runs against the Voxel Tools GDExtension; skip with `-i res://test/integration/test_voxel_smoke.gd`
# if the extension is not installed (ci/fetch_voxel.sh).
extends GdUnitTestSuite

const GROUND_HEIGHT := 8.0 # voxels with y < 8 are solid; top solid layer is y = 7
const SOLID := 1
const AIR := 0
const LOAD_TIMEOUT_MS := 15000
const SAVE_TIMEOUT_MS := 10000
const TMP_DIR := "user://test_tmp/voxel_smoke"

var _root: Node3D


class FallingBody:
	extends CharacterBody3D
	const GRAVITY := 24.0

	func _physics_process(delta: float) -> void:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP_DIR))
	_root = auto_free(Node3D.new())
	add_child(_root)


func after_test() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	await get_tree().process_frame


func _db_path(file_name: String) -> String:
	return ProjectSettings.globalize_path("%s/%s" % [TMP_DIR, file_name])


func _remove_db(path: String) -> void:
	for suffix in ["", "-journal", "-wal", "-shm"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func _make_terrain(db_path: String) -> VoxelTerrain:
	var lib := VoxelBlockyLibrary.new()
	lib.add_model(VoxelBlockyModelEmpty.new())
	lib.add_model(VoxelBlockyModelCube.new())
	lib.bake()
	var mesher := VoxelMesherBlocky.new()
	mesher.library = lib
	var gen := VoxelGeneratorFlat.new()
	gen.channel = VoxelBuffer.CHANNEL_TYPE
	gen.voxel_type = SOLID
	gen.height = GROUND_HEIGHT
	var terrain := VoxelTerrain.new()
	terrain.mesher = mesher
	terrain.generator = gen
	terrain.max_view_distance = 32
	terrain.bounds = AABB(Vector3(-32, -16, -32), Vector3(64, 48, 64))
	terrain.generate_collisions = true
	if db_path != "":
		var stream := VoxelStreamSQLite.new()
		stream.database_path = db_path
		terrain.stream = stream
	_root.add_child(terrain)
	var viewer := VoxelViewer.new()
	viewer.position = Vector3(0, 10, 0)
	terrain.add_child(viewer)
	return terrain


func _tool(terrain: VoxelTerrain) -> VoxelTool:
	var vt := terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE
	return vt


func _await_loaded(terrain: VoxelTerrain, area: AABB) -> bool:
	var vt := _tool(terrain)
	var start := Time.get_ticks_msec()
	while not vt.is_area_editable(area):
		if Time.get_ticks_msec() - start > LOAD_TIMEOUT_MS:
			return false
		await get_tree().process_frame
	return true


func _await_save(terrain: VoxelTerrain) -> bool:
	var tracker := terrain.save_modified_blocks()
	var start := Time.get_ticks_msec()
	while not tracker.is_complete():
		if tracker.is_aborted() or Time.get_ticks_msec() - start > SAVE_TIMEOUT_MS:
			return false
		await get_tree().process_frame
	return true


const AREA := AABB(Vector3(-8, 0, -8), Vector3(16, 12, 16))


# P0.8 a
func test_extension_classes_are_registered() -> void:
	for cls in ["VoxelTerrain", "VoxelMesherBlocky", "VoxelBlockyLibrary", "VoxelStreamSQLite", "VoxelAStarGrid3D", "VoxelViewer", "VoxelGeneratorScript"]:
		assert_bool(ClassDB.class_exists(cls)).override_failure_message("missing class %s" % cls).is_true()


# P0.8 c
func test_dig_place_and_raycast() -> void:
	var terrain := _make_terrain("")
	assert_bool(await _await_loaded(terrain, AREA)).is_true()
	var vt := _tool(terrain)

	assert_int(vt.get_voxel(Vector3i(0, 7, 0))).is_equal(SOLID)
	assert_int(vt.get_voxel(Vector3i(0, 8, 0))).is_equal(AIR)

	vt.set_voxel(Vector3i(0, 7, 0), AIR)
	vt.set_voxel(Vector3i(2, 8, 0), SOLID)
	assert_int(vt.get_voxel(Vector3i(0, 7, 0))).is_equal(AIR)
	assert_int(vt.get_voxel(Vector3i(2, 8, 0))).is_equal(SOLID)

	var hit_untouched := vt.raycast(Vector3(4.5, 20, 4.5), Vector3.DOWN, 30.0)
	assert_object(hit_untouched).is_not_null()
	assert_vector(hit_untouched.position).is_equal(Vector3i(4, 7, 4))

	var hit_dug := vt.raycast(Vector3(0.5, 20, 0.5), Vector3.DOWN, 30.0)
	assert_vector(hit_dug.position).is_equal(Vector3i(0, 6, 0))
	assert_vector(hit_dug.previous_position).is_equal(Vector3i(0, 7, 0))

	var hit_placed := vt.raycast(Vector3(2.5, 20, 0.5), Vector3.DOWN, 30.0)
	assert_vector(hit_placed.position).is_equal(Vector3i(2, 8, 0))


# P0.8 e, f
func test_sqlite_save_reload_and_copy_while_attached() -> void:
	var db := _db_path("slot.voxels.sqlite")
	var copy := _db_path("slot_copy.voxels.sqlite")
	_remove_db(db)
	_remove_db(copy)

	var terrain := _make_terrain(db)
	assert_bool(await _await_loaded(terrain, AREA)).is_true()
	var vt := _tool(terrain)
	vt.set_voxel(Vector3i(1, 7, 1), AIR)
	vt.set_voxel(Vector3i(-3, 8, 2), SOLID)

	var t0 := Time.get_ticks_usec()
	assert_bool(await _await_save(terrain)).is_true()
	print("[voxel_spike] save_modified_blocks completed in %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))

	var side_files: Array[String] = []
	for suffix in ["-journal", "-wal", "-shm"]:
		if FileAccess.file_exists(db + suffix):
			side_files.append(suffix)
	print("[voxel_spike] sqlite side files present while attached: %s" % [side_files])

	# Copy while the stream is still attached (spec 0.6 item 22).
	assert_int(DirAccess.copy_absolute(db, copy)).is_equal(OK)
	terrain.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	var reloaded := _make_terrain(copy)
	assert_bool(await _await_loaded(reloaded, AREA)).is_true()
	var vt2 := _tool(reloaded)
	assert_int(vt2.get_voxel(Vector3i(1, 7, 1))).is_equal(AIR)
	assert_int(vt2.get_voxel(Vector3i(-3, 8, 2))).is_equal(SOLID)
	assert_int(vt2.get_voxel(Vector3i(5, 7, 5))).is_equal(SOLID)


# P0.8 g
func test_astar_path_on_blocky_terrain() -> void:
	var terrain := _make_terrain("")
	assert_bool(await _await_loaded(terrain, AREA)).is_true()
	var vt := _tool(terrain)
	# A 3-high wall the 1x2 agent cannot jump, with a gap at z = 4.
	for z in range(-6, 7):
		if z == 4:
			continue
		for y in range(8, 11):
			vt.set_voxel(Vector3i(0, y, z), SOLID)

	var astar := VoxelAStarGrid3D.new()
	astar.set_terrain(terrain)
	astar.set_region(AABB(Vector3(-8, 0, -8), Vector3(16, 12, 16)))
	var path := astar.find_path(Vector3i(-4, 8, 0), Vector3i(4, 8, 0))
	print("[voxel_spike] A* path length %d" % path.size())
	assert_int(path.size()).is_greater(0)
	assert_bool(path.has(Vector3i(0, 8, 4))).override_failure_message("path should go through the gap").is_true()


# P0.8 h (Jolt in headless, static ground)
func test_jolt_character_lands_on_static_floor_headless() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	_root.add_child(floor_body)

	var body := FallingBody.new()
	var cap_shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 2.1
	cap.radius = 0.35
	cap_shape.shape = cap
	body.add_child(cap_shape)
	body.position = Vector3(0, 4, 0)
	_root.add_child(body)

	await PhysicsWait.frames(get_tree(), 120)
	assert_bool(body.is_on_floor()).is_true()
	assert_float(body.position.y).is_equal_approx(0.5 + 1.05, 0.06)


# P0.8 h + d (voxel collision headless and edit-to-collision latency)
func test_character_on_voxel_collision_and_dig_latency() -> void:
	var terrain := _make_terrain("")
	assert_bool(await _await_loaded(terrain, AREA)).is_true()
	# Wait until the area is meshed, which is when collision shapes exist.
	var start := Time.get_ticks_msec()
	while not terrain.is_area_meshed(AREA):
		if Time.get_ticks_msec() - start > LOAD_TIMEOUT_MS:
			break
		await get_tree().process_frame
	assert_bool(terrain.is_area_meshed(AREA)).override_failure_message("area never meshed headless").is_true()

	var body := FallingBody.new()
	var cap_shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 2.1
	cap.radius = 0.35
	cap_shape.shape = cap
	body.add_child(cap_shape)
	body.position = Vector3(0.5, 12, 0.5)
	_root.add_child(body)

	await PhysicsWait.frames(get_tree(), 120)
	assert_bool(body.is_on_floor()).override_failure_message("no voxel collision headless").is_true()
	assert_float(body.position.y).is_equal_approx(GROUND_HEIGHT + 1.05, 0.06)

	# Dig a 3x3 pit under the body and measure physics frames until it starts falling.
	var vt := _tool(terrain)
	var t0 := Time.get_ticks_usec()
	for x in range(-1, 2):
		for z in range(-1, 2):
			vt.set_voxel(Vector3i(x, 7, z), AIR)
	# Collision is considered updated on the first physics frame the body is no longer on the floor.
	var frames := 0
	while body.is_on_floor() and frames < 120:
		await get_tree().physics_frame
		frames += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("[voxel_spike] edit-to-collision: %d physics frames, %.1f ms (this machine; budget 100 ms on min spec)" % [frames, ms])
	assert_int(frames).is_less(120)


# ---- P2.33: generators and TerrainService on real Voxel Tools terrain

func _ids() -> Dictionary:
	var ids := {}
	for m in Database.materials.values():
		ids[String(m.id)] = m.voxel_id
	return ids


func test_overworld_generator_bedrock_and_surface() -> void:
	var gen := OverworldGenerator.new(_ids(), -24, 77)
	var terrain := VoxelTerrain.new()
	var mesher := VoxelMesherBlocky.new()
	mesher.library = VoxelLibraryBuilder.build()
	terrain.mesher = mesher
	terrain.generator = gen
	terrain.max_view_distance = 32
	terrain.bounds = AABB(Vector3(-16, -24, -16), Vector3(32, 48, 32))
	_root.add_child(terrain)
	var viewer := VoxelViewer.new()
	terrain.add_child(viewer)
	assert_bool(await _await_loaded(terrain, AABB(Vector3(-4, -24, -4), Vector3(8, 40, 8)))).is_true()
	var w := VoxelWorldAdapter.new(terrain)
	var h := gen.height_at(0, 0)
	assert_int(w.get_voxel(Vector3i(0, h, 0))).is_equal(Database.voxel_id_of(&"mat_grass"))
	assert_int(w.get_voxel(Vector3i(0, h + 1, 0))).is_equal(0)
	assert_int(w.get_voxel(Vector3i(0, -24, 0))).is_equal(Database.voxel_id_of(&"mat_bedrock"))


func test_terrain_service_with_real_adapter_respects_protection() -> void:
	var gen := OverworldGenerator.new(_ids(), -24, 77)
	var terrain := VoxelTerrain.new()
	var mesher := VoxelMesherBlocky.new()
	mesher.library = VoxelLibraryBuilder.build()
	terrain.mesher = mesher
	terrain.generator = gen
	terrain.max_view_distance = 32
	_root.add_child(terrain)
	terrain.add_child(VoxelViewer.new())
	assert_bool(await _await_loaded(terrain, AABB(Vector3(-4, -24, -4), Vector3(8, 40, 8)))).is_true()
	var session := GameSession.create(5, VoxelWorldAdapter.new(terrain))
	_root.add_child(session)
	session.new_game()
	var h := gen.height_at(1, 1)
	session.terrain.rules.add_volume(Vector3i(0, -30, 0), Vector3i(0, 40, 0), &"TOWN")
	var shovel := session.toolbelt.model.tool_data(ToolTypes.SHOVEL)
	assert_str(session.terrain.hit_voxel(Vector3i(0, gen.height_at(0, 0), 0), shovel)["result"]).is_equal(TerrainRules.PROTECTED)
	session.terrain.hit_voxel(Vector3i(1, h, 1), shovel)
	assert_str(session.terrain.hit_voxel(Vector3i(1, h, 1), shovel)["result"]).is_equal(VoxelDigModel.DUG)
	assert_int(session.terrain.world.get_voxel(Vector3i(1, h, 1))).is_equal(0)
	assert_int(session.inventory.count(&"item_dirt")).is_equal(1)


func test_real_zones_load_and_player_stands() -> void:
	var session := GameSession.create(11)
	_root.add_child(session)
	session.new_game()
	var zone_root := Node3D.new()
	_root.add_child(zone_root)
	SceneRouter.reset_for_tests()
	SceneRouter.fade_duration = 0.0
	SceneRouter.zone_root = zone_root
	var player: PlayerController = preload("res://scenes/player/player.tscn").instantiate()
	_root.add_child(player)
	player.tool_selector.set_aim_for_tests(Vector3(0, 1000, 0), Vector3.UP)
	SceneRouter.player = player
	await SceneRouter.change_zone(&"zone_wilderness", &"spawn_start")
	var zone: Zone = SceneRouter.current_zone
	assert_object(zone.terrain_node).is_not_null()
	var start := Time.get_ticks_msec()
	while not (zone.terrain_node as VoxelTerrain).is_area_meshed(AABB(Vector3(-4, -10, -4), Vector3(8, 24, 8))) and Time.get_ticks_msec() - start < LOAD_TIMEOUT_MS:
		await get_tree().process_frame
	await PhysicsWait.frames(get_tree(), 90)
	assert_bool(player.is_on_floor()).override_failure_message("player not standing on generated terrain").is_true()
	var surface := (zone.generator as OverworldGenerator).height_at(0, 0) + 1
	assert_float(player.global_position.y).is_equal_approx(float(surface), 0.1)
	await SceneRouter.change_zone(&"zone_deep_mine", &"spawn_entry")
	assert_str(SceneRouter.current_zone_id).is_equal(&"zone_deep_mine")
	var mine: Zone = SceneRouter.current_zone
	assert_int((mine.generator as DeepMineGenerator).voxel_at(1, -36, 1)).override_failure_message("spawn must be inside a tunnel").is_equal(0)
	assert_int((mine.generator as DeepMineGenerator).voxel_at(1, -37, 1)).is_not_equal(0)
	SceneRouter.reset_for_tests()
	SceneRouter.player = null
	SceneRouter.zone_root = null


# P2B.2: Home Meadow on real Voxel Tools terrain: the starter garden is level grass and
# farmable, the cabin exterior is protected, and the player tills a real voxel.
func test_home_meadow_garden_is_level_and_farmable() -> void:
	var session := GameSession.create(11)
	_root.add_child(session)
	session.new_game()
	var zone_root := Node3D.new()
	_root.add_child(zone_root)
	SceneRouter.reset_for_tests()
	SceneRouter.fade_duration = 0.0
	SceneRouter.zone_root = zone_root
	var player: PlayerController = preload("res://scenes/player/player.tscn").instantiate()
	_root.add_child(player)
	player.tool_selector.set_aim_for_tests(Vector3(0, 1000, 0), Vector3.UP)
	SceneRouter.player = player
	await SceneRouter.change_zone(&"zone_home_meadow", &"spawn_start")
	var zone: Zone = SceneRouter.current_zone
	var gen := zone.generator as OverworldGenerator
	var plot: PlotDef = Database.plots[&"plot_starter_garden"]
	var t := zone.terrain_node as VoxelTerrain
	var area := AABB(Vector3(plot.min_cell.x, -10, plot.min_cell.z), Vector3(8, 30, 8))
	var start := Time.get_ticks_msec()
	while not t.is_area_meshed(area) and Time.get_ticks_msec() - start < LOAD_TIMEOUT_MS:
		await get_tree().process_frame
	var h := gen.height_at(plot.min_cell.x, plot.min_cell.z)
	for x in range(plot.min_cell.x, plot.max_cell.x + 1):
		for z in range(plot.min_cell.z, plot.max_cell.z + 1):
			assert_int(gen.height_at(x, z)).is_equal(h)
	var soil := Vector3i(plot.min_cell.x + 2, h, plot.min_cell.z + 2)
	assert_int(session.terrain.world.get_voxel(soil)).is_equal(Database.voxel_id_of(&"mat_grass"))
	assert_str(session.farm.farmable_reason(soil)).is_equal(&"")
	assert_bool(session.farm.try_till(soil, &"").ok).is_true()
	assert_int(session.terrain.world.get_voxel(soil)).is_equal(Database.voxel_id_of(&"mat_farmland"))
	assert_object(zone.find_child("Well", true, false)).is_not_null()
	assert_object(zone.get_node_or_null("FarmView")).is_not_null()
	var cabin_x := -5
	assert_str(session.terrain.can_dig(Vector3i(cabin_x, gen.height_at(cabin_x, -3), -3))).is_equal(TerrainRules.PROTECTED)
	SceneRouter.reset_for_tests()
	SceneRouter.player = null
	SceneRouter.zone_root = null
