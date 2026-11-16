## Tall-character controller (spec 1.4, 4.2). Each physics tick:
## read InputFrame -> resolve toggles and timers -> probe the world into PlayerContext ->
## ask PlayerTransitionTable -> move the CharacterBody3D. All rules live in pure models.
class_name PlayerController
extends CharacterBody3D

signal feedback(effect: StringName)   # bump, low_ceiling, soft_land: pictogram hooks for HUD

const MASK_SOLID := 1 | 64   # layers world (1) and build_pieces (7)

@export var config: PlayerConfig = preload("res://resources/config/player_config.tres")
@export var jump_config: JumpConfig = preload("res://resources/config/jump_config.tres")

var jump := JumpModel.new()
var run_toggle := ToggleHoldModel.new()
var duck_toggle := ToggleHoldModel.new()
var context := PlayerContext.new()
var is_ducking := false
var jumped_this_tick := false
var jump_auto := true

var _was_on_floor := true
var _fall_peak_y := 0.0
var _landing_fall_height := 0.0   # set on the landing tick, read by the next transition
var _air_speed := 2.2
var _toward_ledge_time := 0.0
var _since_manual_jump := 10.0
var _facing_yaw := 0.0

# Phase 2
var yawn_seconds := 1.5
var pending_sleep_reason: StringName = &"exhausted"
var last_safe_position := Vector3.ZERO
var stuck := StuckDetector.new()
var _forced_sleep: StringName = &""
var _last_alt := false
var _focused: Interactable
var _target: Dictionary = {}     # current tool target: {"kind": &"voxel", "cell"} or {"kind": &"zone", "node"}
var _safe_timer := 0.0
var _target_destroyed := false

@onready var machine: StateMachine = $StateMachine
@onready var input_reader: InputReader = $InputReader
@onready var camera_rig: CameraRig = $CameraRig
@onready var collision_standing: CollisionShape3D = $CollisionStanding
@onready var collision_ducking: CollisionShape3D = $CollisionDucking
@onready var head_clearance: ShapeCast3D = $HeadClearance
@onready var jump_clearance: ShapeCast3D = $JumpClearance
@onready var visual: Node3D = $Visual
@onready var tool_selector: ToolAutoSelector = $ToolAutoSelector
@onready var tool_detector: Area3D = $ToolDetector
@onready var interaction_probe: Area3D = $InteractionProbe


func _ready() -> void:
	jump.configure(jump_config)
	_air_speed = config.walk_speed
	for s in machine.states.values():
		(s as PlayerState).player = self
	machine.transitioned.connect(_on_transitioned)
	camera_rig.setup(config, self)
	apply_settings()
	EventBus.settings_changed.connect(func(_s, _k, _v): apply_settings())
	_was_on_floor = true
	_fall_peak_y = global_position.y
	tool_selector.setup(self, tool_detector)
	EventBus.player_woke.connect(_on_woke)
	last_safe_position = global_position
	if GameSession.current:
		GameSession.current.player = self


func apply_settings() -> void:
	run_toggle.mode = StringName(Settings.get_value("input", "run_mode"))
	duck_toggle.mode = StringName(Settings.get_value("input", "duck_mode"))
	jump_auto = bool(Settings.get_value("input", "jump_auto"))
	camera_rig.sensitivity = float(Settings.get_value("input", "sensitivity"))
	camera_rig.invert_y = bool(Settings.get_value("input", "invert_y"))


func current_state() -> PlayerState:
	return machine.current as PlayerState


func _physics_process(delta: float) -> void:
	jumped_this_tick = false
	var f := input_reader.read_frame()
	jump.tick(delta)
	_since_manual_jump += delta
	_update_toggles(f)
	camera_rig.apply_input(f, delta, _facing_yaw)
	_build_context(f, delta)
	_build_phase2_context(f, delta)

	var t := PlayerTransitionTable.next(machine.current_id, f, context)
	if t.stays():
		_apply_stay_effect(t.effect)
	elif machine.has_state(t.to):
		if t.to == PlayerTransitionTable.MINE:
			tool_selector.commit_now()
		machine.transition_to(t.to, {"effect": t.effect, "from": machine.current_id, "auto": context.auto_jump_ready and not f.jump_pressed, "reason": pending_sleep_reason})
		if t.effect == PlayerTransitionTable.FX_SOFT_LAND:
			feedback.emit(t.effect)
	current_state().physics_tick(delta, f)

	_move(f, delta)
	_after_move()


func _update_toggles(f: InputFrame) -> void:
	var moving := f.move.length() > PlayerTransitionTable.MOVE_THRESHOLD
	run_toggle.update(f.run_pressed, f.run_held)
	if not moving and run_toggle.mode == ToggleHoldModel.TOGGLE:
		run_toggle.reset()   # spec 4.2: run toggle resets when the player stops
	duck_toggle.update(f.duck_pressed, f.duck_held)


func _build_context(f: InputFrame, delta: float) -> void:
	var c := context
	c.move_len = f.move.length()
	c.wants_run = run_toggle.active and not duck_toggle.active
	c.wants_duck = duck_toggle.active
	c.is_ducking = is_ducking
	c.on_floor = is_on_floor()
	c.vertical_velocity = velocity.y
	c.ceiling_hit = is_on_ceiling() and velocity.y > 0.0
	c.coyote_left = jump.coyote_left
	c.jump_buffered = jump.is_buffered()
	c.air_jumps_left = jump.air_jumps_left
	c.fall_height = _landing_fall_height if c.on_floor else 0.0
	c.head_clear = not _probe_collides(head_clearance)
	c.headroom_ok = not _probe_collides(jump_clearance)

	var dir := camera_rig.move_direction(f.move)
	var ledge := _probe_ledge(dir) if dir.length() > 0.1 else {"step": false, "above": false, "clear": false}
	if ledge["step"] and c.move_len > PlayerTransitionTable.MOVE_THRESHOLD:
		_toward_ledge_time += delta
	else:
		_toward_ledge_time = 0.0
	c.auto_jump_ready = LedgeModel.should_auto_jump(
		jump_auto, c.on_floor, is_ducking, ledge["step"], ledge["above"], ledge["clear"],
		_toward_ledge_time, _since_manual_jump)


func _apply_stay_effect(effect: StringName) -> void:
	match effect:
		PlayerTransitionTable.FX_BUFFER:
			jump.buffer_press()
		PlayerTransitionTable.FX_BUMP, PlayerTransitionTable.FX_LOW_CEILING:
			feedback.emit(effect)
		PlayerTransitionTable.FX_CEILING:
			velocity.y = minf(velocity.y, 0.0)
		PlayerTransitionTable.FX_AIR_STRIKE:
			tool_selector.commit_now()
			perform_strike()
		PlayerTransitionTable.FX_BLOCKED, PlayerTransitionTable.FX_TIER_LOW:
			feedback.emit(effect)


func _move(f: InputFrame, delta: float) -> void:
	var state := current_state()
	var dir := camera_rig.move_direction(f.move)
	var horizontal := Vector2(velocity.x, velocity.z)
	var accel := config.ground_accel
	var speed := state.move_speed()
	if state.is_airborne():
		speed = _air_speed
		accel *= jump_config.air_control
	var target := Vector2(dir.x, dir.z) * speed
	horizontal = horizontal.move_toward(target, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	if state.is_airborne() or not is_on_floor():
		if not jumped_this_tick:
			velocity.y = jump.apply_gravity(velocity.y, delta)
	else:
		velocity.y = 0.0

	if dir.length() > 0.1:
		_facing_yaw = atan2(-dir.x, -dir.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, _facing_yaw, clampf(12.0 * delta, 0.0, 1.0))
	move_and_slide()


func _after_move() -> void:
	var on_floor_now := is_on_floor()
	if on_floor_now and not _was_on_floor:
		jump.landed()
		_landing_fall_height = maxf(0.0, _fall_peak_y - global_position.y)
	else:
		_landing_fall_height = 0.0
		if not on_floor_now and _was_on_floor and not jumped_this_tick:
			jump.left_floor_without_jump()
	if on_floor_now:
		_fall_peak_y = global_position.y
	else:
		_fall_peak_y = maxf(_fall_peak_y, global_position.y)
	_was_on_floor = on_floor_now
	_track_safe_ground(get_physics_process_delta_time())


## Called by the Jump state on a ground jump.
func capture_air_speed() -> void:
	_air_speed = maxf(Vector2(velocity.x, velocity.z).length(), config.walk_speed)


func note_manual_or_auto_jump(_auto: bool) -> void:
	_since_manual_jump = 0.0
	_toward_ledge_time = 0.0


## Called by the Duck state. Collider changes are deferred (safe inside physics callbacks).
func set_ducking(on: bool) -> void:
	is_ducking = on
	collision_standing.set_deferred("disabled", on)
	collision_ducking.set_deferred("disabled", not on)
	camera_rig.set_ducking(config, on)


func _on_transitioned(from: StringName, to: StringName) -> void:
	EventBus.player_state_changed.emit(from, to)


func _probe_collides(cast: ShapeCast3D) -> bool:
	cast.force_shapecast_update()
	return cast.is_colliding()


## Ledge probes for auto-jump, in the move direction.
func _probe_ledge(dir: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var origin := global_position
	var ahead := dir.normalized() * (config.radius + 0.4)
	var exclude: Array[RID] = [get_rid()]
	var foot := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.5, origin + Vector3.UP * 0.5 + ahead, MASK_SOLID, exclude)
	var above := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 1.5, origin + Vector3.UP * 1.5 + ahead, MASK_SOLID, exclude)
	var step := not space.intersect_ray(foot).is_empty()
	var above_free := space.intersect_ray(above).is_empty()
	var clear := false
	if step and above_free:
		var box := BoxShape3D.new()
		box.size = Vector3(config.radius * 2.0, config.standing_height, config.radius * 2.0)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = box
		q.collision_mask = MASK_SOLID
		q.exclude = exclude
		q.transform = Transform3D(Basis(), origin + ahead + Vector3.UP * (1.0 + config.standing_height * 0.5 + 0.05))
		clear = space.intersect_shape(q, 1).is_empty()
	return {"step": step, "above": above_free, "clear": clear}


# ---------------------------------------------------------------- Phase 2 integration

func session() -> GameSession:
	return GameSession.current


func _build_phase2_context(f: InputFrame, delta: float) -> void:
	var c := context
	var s := session()
	_last_alt = f.interact_alt_pressed
	c.tool_target_kind = &""
	c.tool_ok = false
	c.tool_blocked = &""
	c.has_interact_target = false
	c.exhaustion_pending = _forced_sleep != &""
	if s == null:
		return
	c.exhaustion_pending = c.exhaustion_pending or s.stamina.exhaustion_pending
	var feet := IVoxelWorld.cell_of(global_position + Vector3(0, -0.1, 0))
	s.terrain.rules.player_feet_cell = feet
	s.terrain.rules.player_cells = [feet + Vector3i.UP, feet + Vector3i(0, 2, 0), feet + Vector3i(0, 3, 0)]

	tool_selector.tick(delta, current_state().locks_tool())
	var aim := tool_selector.last_aim
	var best := tool_selector.best()
	# Spec 4.3: while mining, the target is pinned until destroyed; only then may it retarget.
	if machine.current_id == PlayerTransitionTable.MINE and not _target.is_empty() and not _target_destroyed and mine_target_valid():
		c.tool_target_kind = PlayerTransitionTable.TARGET_VOXEL if _target["kind"] == &"voxel" else PlayerTransitionTable.TARGET_TIMBER
		c.tool_ok = true
		return
	_target_destroyed = false
	_target = {}
	if not aim.is_empty() and aim.get("blocked", &"") != &"":
		c.tool_target_kind = PlayerTransitionTable.TARGET_VOXEL
		c.tool_blocked = aim["blocked"]
	elif not best.is_empty():
		var belt := s.toolbelt.model
		match best["target_kind"]:
			&"voxel_soft", &"voxel_hard":
				if aim.get("key", "") == best["key"]:
					_target = {"kind": &"voxel", "cell": aim["cell"]}
					c.tool_target_kind = PlayerTransitionTable.TARGET_VOXEL
					var mat := s.terrain.material_at(aim["cell"])
					var data := belt.tool_data(best["tool"])
					c.tool_ok = mat != null and data != null and VoxelDigModel.tool_can_dig(mat, data) == &""
			&"timber":
				_target = {"kind": &"zone", "node": _zone_node(best["key"], aim)}
				c.tool_target_kind = PlayerTransitionTable.TARGET_TIMBER
				c.tool_ok = belt.has_tool(ToolTypes.AXE)
			&"fruit_tree":
				_target = {"kind": &"zone", "node": _zone_node(best["key"], aim)}
				c.tool_target_kind = PlayerTransitionTable.TARGET_FRUIT_TREE
				c.tool_ok = true
	if f.interact_pressed or f.interact_alt_pressed or f.use_pressed:
		_focused = _resolve_focus(f.use_pressed and c.tool_target_kind == PlayerTransitionTable.TARGET_FRUIT_TREE)
		c.has_interact_target = _focused != null and _focused.spec_for(self, false, f.interact_alt_pressed) != null
	var enclosed := _enclosed()
	if stuck.update(delta, f.move.length() > 0.2, global_position, enclosed):
		EventBus.stuck_hint.emit()


func _zone_node(key: String, aim: Dictionary) -> Node:
	if aim.get("key", "") == key and aim.has("node"):
		return aim["node"]
	return tool_selector._tracked.get(key)


## Focused interactable (spec 4.5). With `prefer_tree`, the tool-targeted fruit tree wins.
func _resolve_focus(prefer_tree: bool) -> Interactable:
	if prefer_tree and _target.get("kind") == &"zone" and is_instance_valid(_target.get("node")):
		var tree = _target["node"].get_parent()
		for ch in tree.get_children():
			if ch is Interactable:
				return ch
	var cands: Array = []
	var lookup := {}
	var fwd := Vector3(-sin(_facing_yaw), 0, -cos(_facing_yaw))
	for a in interaction_probe.get_overlapping_areas():
		if a is Interactable:
			var to := a.global_position - global_position
			var flat := Vector3(to.x, 0, to.z)
			var dot := fwd.dot(flat.normalized()) if flat.length() > 0.01 else 1.0
			cands.append({"key": a.key if a.key != "" else str(a.get_instance_id()), "kind": a.kind, "distance": to.length(), "facing_dot": dot, "aimed": false})
			lookup[cands.back()["key"]] = a
	var best := InteractionResolver.best(cands)
	return lookup.get(best.get("key", ""))


func focused_interactable() -> Interactable:
	return _focused


func last_frame_alt() -> bool:
	return _last_alt


func face_towards(target: Vector3) -> void:
	var d := target - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		_facing_yaw = atan2(-d.x, -d.z)
		visual.rotation.y = _facing_yaw


func equipped_tool_data() -> ToolData:
	var s := session()
	return s.toolbelt.model.equipped_data() if s else null


func mine_target_valid() -> bool:
	var s := session()
	if s == null or _target.is_empty():
		return false
	if _target["kind"] == &"voxel":
		return s.terrain.can_dig(_target["cell"]) == TerrainRules.OK
	var n = _target.get("node")
	return is_instance_valid(n) and n.is_active()


## One dig or chop strike on the current target. Returns true if the target was destroyed.
func perform_strike() -> bool:
	var s := session()
	if s == null or _target.is_empty() or not s.stamina.can_act():
		return false
	var data := equipped_tool_data()
	if _target["kind"] == &"voxel":
		var cell: Vector3i = _target["cell"]
		var mat := s.terrain.material_at(cell)
		var r := s.terrain.hit_voxel(cell, data)
		if r["result"] == VoxelDigModel.DAMAGED or r["result"] == VoxelDigModel.DUG:
			s.stamina.spend(mat.stamina_cost, &"dig")
		_target_destroyed = r["result"] == VoxelDigModel.DUG
		return _target_destroyed
	var zone = _target.get("node")
	if not is_instance_valid(zone) or zone.target_kind != &"timber" or data == null or data.tool_type != ToolTypes.AXE:
		return false
	var cr := s.world_state.chop(zone.key, data.power, zone.global_position)
	if cr["result"] != &"gone":
		s.stamina.spend(data.stamina_cost, &"chop")
	_target_destroyed = cr["result"] == &"felled"
	return _target_destroyed


## Late night (spec 6.2): sleep once grounded.
func request_sleep(reason: StringName) -> void:
	pending_sleep_reason = reason
	_forced_sleep = reason


func _on_woke(_reason: StringName, _day: int) -> void:
	pending_sleep_reason = &"exhausted"
	_forced_sleep = &""
	context.mine_done = false
	context.interact_done = false
	duck_toggle.reset()
	run_toggle.reset()
	velocity = Vector3.ZERO
	if machine.current_id != &"idle":
		machine.transition_to(&"idle", {})
	input_reader.arm_resume_guard(Engine.get_physics_frames())
	last_safe_position = global_position


func return_to_safe_ground() -> void:
	var s := session()
	if s:
		s.sleep.return_to_safe(self, last_safe_position)


func _track_safe_ground(delta: float) -> void:
	_safe_timer += delta
	if _safe_timer < 0.5:
		return
	_safe_timer = 0.0
	if is_on_floor() and not is_ducking and not _probe_collides(head_clearance):
		last_safe_position = global_position


func _enclosed() -> bool:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 1.0
	var ex: Array[RID] = [get_rid()]
	for d in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + d * 0.7, MASK_SOLID, ex)
		if space.intersect_ray(q).is_empty():
			return false
	return _probe_collides(jump_clearance)


## What the prompt overlay should show this frame (spec 2.8).
func prompt_target() -> Dictionary:
	var s := session()
	if s == null:
		return {}
	var best := tool_selector.best()
	var aim := tool_selector.last_aim
	var focus := _resolve_focus(false)
	var blocked: StringName = aim.get("blocked", &"") if not aim.is_empty() else &""
	var pos := Vector3.ZERO
	if focus:
		pos = focus.global_position
	elif not aim.is_empty() and aim.has("cell"):
		pos = Vector3(aim["cell"]) + Vector3(0.5, 1.0, 0.5)
	elif not best.is_empty() and _zone_node(best["key"], aim):
		pos = _zone_node(best["key"], aim).global_position + Vector3(0, 1, 0)
	else:
		return {}
	return {"position": pos, "tool": best if blocked == &"" else {}, "blocked": blocked,
		"primary": focus.spec_for(self, false, false) if focus else null,
		"secondary": focus.spec_for(self, false, true) if focus else null}
