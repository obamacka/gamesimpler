# P1.29: the player in the graybox room, driven by injected InputFrames (no InputEvents).
extends GdUnitTestSuite

const Room = preload("res://scenes/dev/locomotion_room.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ROOM_SCENE := preload("res://scenes/dev/locomotion_room.tscn")
const OPEN_FLOOR := Vector3(20, 0, 10)   # nothing in front along -Z

var _room: Node3D
var _player: PlayerController


func before_test() -> void:
	Settings.model.reset()
	PauseManager.reset_for_tests()
	_room = auto_free(ROOM_SCENE.instantiate())
	add_child(_room)
	_player = auto_free(PLAYER_SCENE.instantiate())
	add_child(_player)


func after_test() -> void:
	Settings.model.reset()


func _spawn(pos: Vector3, jump_auto: bool = false) -> void:
	Settings.model.set_value("input", "jump_auto", jump_auto)
	_player.apply_settings()
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	await PhysicsWait.frames(get_tree(), 10)   # settle on the floor


func _frame(move: Vector2 = Vector2.ZERO) -> InputFrame:
	var f := InputFrame.new()
	f.move = move
	return f


func _press(field: String, move: Vector2 = Vector2.ZERO) -> InputFrame:
	var f := _frame(move)
	f.set(field, true)
	return f


func _hold_forward() -> void:
	_player.input_reader.inject_hold(_frame(Vector2(0, -1)))


func _state() -> StringName:
	return _player.machine.current_id


func test_walk_speed() -> void:
	await _spawn(OPEN_FLOOR)
	var z0 := _player.global_position.z
	_hold_forward()
	await PhysicsWait.frames(get_tree(), 60)
	assert_str(_state()).is_equal(&"walk")
	assert_float(z0 - _player.global_position.z).is_between(1.8, 2.3)


func test_run_toggle_and_speed() -> void:
	await _spawn(OPEN_FLOOR)
	_player.input_reader.inject_once(_press("run_pressed", Vector2(0, -1)))
	_hold_forward()
	await PhysicsWait.frames(get_tree(), 20)
	assert_str(_state()).is_equal(&"run")
	var z0 := _player.global_position.z
	await PhysicsWait.frames(get_tree(), 60)
	assert_float(z0 - _player.global_position.z).is_between(4.6, 5.2)


func test_duck_swaps_colliders() -> void:
	await _spawn(OPEN_FLOOR)
	_player.input_reader.inject_once(_press("duck_pressed"))
	_player.input_reader.inject_hold(_frame())
	await PhysicsWait.frames(get_tree(), 5)
	assert_str(_state()).is_equal(&"duck")
	assert_bool(_player.collision_standing.disabled).is_true()
	assert_bool(_player.collision_ducking.disabled).is_false()


func test_standing_player_cannot_enter_tunnel() -> void:
	await _spawn(Room.LANE_TUNNEL + Vector3(0, 0, -1.5))
	_hold_forward()
	await PhysicsWait.frames(get_tree(), 90)
	assert_float(_player.global_position.z).is_greater(Room.STEP_NEAR_Z - 0.1)


func test_duck_through_tunnel_and_cannot_stand_inside() -> void:
	await _spawn(Room.LANE_TUNNEL + Vector3(0, 0, -1.5))
	var feedback: Array = []
	_player.feedback.connect(func(fx): feedback.append(fx))
	_player.input_reader.inject_once(_press("duck_pressed", Vector2(0, -1)))
	_hold_forward()
	await PhysicsWait.frames(get_tree(), 150)   # duck-walk 1.2 m/s for 2.5 s
	assert_float(_player.global_position.z).is_less(-4.0)
	# Toggle duck off inside the tunnel: must stay ducked (no head clearance).
	_player.input_reader.inject_once(_press("duck_pressed", Vector2(0, -1)))
	await PhysicsWait.frames(get_tree(), 5)
	assert_str(_state()).is_equal(&"duck")
	assert_bool(feedback.has(PlayerTransitionTable.FX_LOW_CEILING)).is_true()
	# Keep walking out of the far end (z = -9): stands up automatically.
	await PhysicsWait.frames(get_tree(), 300)
	assert_float(_player.global_position.z).is_less(-9.5)
	assert_str(_state()).is_equal(&"walk")


func test_jump_lands_on_one_metre_step() -> void:
	await _spawn(Room.LANE_STEP_1 + Vector3(0, 0, Room.STEP_NEAR_Z + 0.6))
	_player.input_reader.inject_once(_press("jump_pressed", Vector2(0, -1)))
	_hold_forward()
	await PhysicsWait.frames(get_tree(), 90)
	assert_bool(_player.is_on_floor()).is_true()
	assert_float(_player.global_position.y).is_equal_approx(1.0, 0.05)


func test_double_jump_lands_on_two_metre_step() -> void:
	await _spawn(Room.LANE_STEP_2 + Vector3(0, 0, Room.STEP_NEAR_Z + 0.6))
	_player.input_reader.inject_once(_press("jump_pressed"))
	_player.input_reader.inject_hold(_frame())
	await PhysicsWait.frames(get_tree(), 18)   # near the first apex
	_player.input_reader.inject_once(_press("jump_pressed", Vector2(0, -1)))
	_hold_forward()
	await PhysicsWait.frames(get_tree(), 100)
	assert_float(_player.global_position.y).is_equal_approx(2.0, 0.05)
	assert_int(_player.jump.air_jumps_left).is_equal(1)   # reset on landing


func test_three_metre_step_is_unreachable() -> void:
	await _spawn(Room.LANE_STEP_3 + Vector3(0, 0, Room.STEP_NEAR_Z + 0.6))
	_player.input_reader.inject_once(_press("jump_pressed"))
	_player.input_reader.inject_hold(_frame())
	await PhysicsWait.frames(get_tree(), 18)
	_player.input_reader.inject_once(_press("jump_pressed", Vector2(0, -1)))
	_hold_forward()
	await PhysicsWait.frames(get_tree(), 100)
	assert_float(_player.global_position.y).is_equal_approx(0.0, 0.05)
	assert_float(_player.global_position.z).is_greater(Room.STEP_NEAR_Z - 0.1)


func _walk_off_platform() -> void:
	await _spawn(Room.LANE_PLATFORM + Vector3(0, Room.PLATFORM_HEIGHT, Room.PLATFORM_EDGE_Z + 1.0))
	_hold_forward()
	var frames := 0
	while _player.is_on_floor() and frames < 120:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_player.is_on_floor()).override_failure_message("never left the platform").is_false()


func test_coyote_jump_within_window_is_a_ground_jump() -> void:
	await _walk_off_platform()
	await PhysicsWait.frames(get_tree(), 3)   # 0.05 s, inside the 0.12 s window
	_player.input_reader.inject_once(_press("jump_pressed", Vector2(0, -1)))
	await PhysicsWait.frames(get_tree(), 2)
	assert_str(_state()).is_equal(&"jump")
	assert_float(_player.velocity.y).is_greater(5.0)
	assert_int(_player.jump.air_jumps_left).override_failure_message("ground jump keeps the air jump").is_equal(1)


func test_late_press_after_coyote_is_the_air_jump() -> void:
	await _walk_off_platform()
	await PhysicsWait.frames(get_tree(), 12)   # 0.2 s, past the window
	_player.input_reader.inject_once(_press("jump_pressed", Vector2(0, -1)))
	await PhysicsWait.frames(get_tree(), 2)
	assert_str(_state()).is_equal(&"jump")
	assert_int(_player.jump.air_jumps_left).is_equal(0)


func test_auto_jump_on_climbs_one_metre_step() -> void:
	await _spawn(Room.LANE_STEP_1 + Vector3(0, 0, -1.0), true)
	_hold_forward()
	await PhysicsWait.frames(get_tree(), 150)
	assert_float(_player.global_position.y).is_equal_approx(1.0, 0.05)


func test_auto_jump_off_stays_blocked() -> void:
	await _spawn(Room.LANE_STEP_1 + Vector3(0, 0, -1.0), false)
	_hold_forward()
	await PhysicsWait.frames(get_tree(), 150)
	assert_float(_player.global_position.y).is_equal_approx(0.0, 0.05)


func test_soft_landing_from_five_metres_without_damage_state() -> void:
	var feedback: Array = []
	_player.feedback.connect(func(fx): feedback.append(fx))
	await _walk_off_platform()
	_player.input_reader.inject_hold(_frame())
	var frames := 0
	while not _player.is_on_floor() and frames < 180:
		await get_tree().physics_frame
		frames += 1
	await PhysicsWait.frames(get_tree(), 13)   # landing + 0.2 s
	assert_bool(feedback.has(PlayerTransitionTable.FX_SOFT_LAND)).is_true()
	assert_bool(_state() in [&"idle", &"walk"]).override_failure_message(String(_state())).is_true()
	assert_float(_player.global_position.y).is_equal_approx(0.0, 0.05)


func test_states_emit_on_event_bus() -> void:
	await _spawn(OPEN_FLOOR)
	var rec := SignalRecorder.new(EventBus, [&"player_state_changed"])
	_hold_forward()
	await PhysicsWait.frames(get_tree(), 5)
	rec.stop()
	assert_bool(rec.records.any(func(r): return r["args"] == [&"idle", &"walk"])).is_true()
