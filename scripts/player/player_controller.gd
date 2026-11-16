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

@onready var machine: StateMachine = $StateMachine
@onready var input_reader: InputReader = $InputReader
@onready var camera_rig: CameraRig = $CameraRig
@onready var collision_standing: CollisionShape3D = $CollisionStanding
@onready var collision_ducking: CollisionShape3D = $CollisionDucking
@onready var head_clearance: ShapeCast3D = $HeadClearance
@onready var jump_clearance: ShapeCast3D = $JumpClearance
@onready var visual: Node3D = $Visual


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

	var t := PlayerTransitionTable.next(machine.current_id, f, context)
	if t.stays():
		_apply_stay_effect(t.effect)
	elif machine.has_state(t.to):
		machine.transition_to(t.to, {"effect": t.effect, "from": machine.current_id, "auto": context.auto_jump_ready and not f.jump_pressed})
		if t.effect == PlayerTransitionTable.FX_SOFT_LAND:
			feedback.emit(t.effect)

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
