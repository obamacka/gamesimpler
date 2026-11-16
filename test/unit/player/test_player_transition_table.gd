# P1.25: locomotion and airborne transition rules and invariants (spec 4.2, 4.2.1).
extends GdUnitTestSuite

const T = preload("res://scripts/player/models/player_transition_table.gd")


func _f(move: Vector2 = Vector2.ZERO, jump := false) -> InputFrame:
	var f := InputFrame.new()
	f.move = move
	f.jump_pressed = jump
	return f


func _c(overrides: Dictionary = {}) -> PlayerContext:
	var c := PlayerContext.new()
	for k in overrides:
		c.set(k, overrides[k])
	return c


func _next(state: StringName, f: InputFrame, c: PlayerContext) -> PlayerTransitionTable.Transition:
	return T.next(state, f, c)


func test_idle_walk_run_thresholds() -> void:
	assert_str(_next(T.IDLE, _f(), _c({"move_len": 0.2})).to).is_equal(&"")
	assert_str(_next(T.IDLE, _f(), _c({"move_len": 0.21})).to).is_equal(T.WALK)
	assert_str(_next(T.WALK, _f(), _c({"move_len": 0.2})).to).is_equal(T.IDLE)
	assert_str(_next(T.WALK, _f(), _c({"move_len": 0.8, "wants_run": true})).to).is_equal(T.RUN)
	assert_str(_next(T.RUN, _f(), _c({"move_len": 0.8, "wants_run": false})).to).is_equal(T.WALK)
	assert_str(_next(T.RUN, _f(), _c({"move_len": 0.1, "wants_run": true})).to).is_equal(T.IDLE)


func test_idle_never_jumps_to_run_directly() -> void:
	assert_str(_next(T.IDLE, _f(), _c({"move_len": 1.0, "wants_run": true})).to).is_equal(T.WALK)


func test_duck_from_each_grounded_state() -> void:
	for s in [T.IDLE, T.WALK, T.RUN]:
		assert_str(_next(s, _f(), _c({"move_len": 0.8, "wants_duck": true, "wants_run": true})).to).override_failure_message(s).is_equal(T.DUCK)


func test_duck_exit_requires_head_clear() -> void:
	var blocked := _next(T.DUCK, _f(), _c({"wants_duck": false, "head_clear": false}))
	assert_str(blocked.to).is_equal(&"")
	assert_str(blocked.effect).is_equal(T.FX_LOW_CEILING)
	assert_str(_next(T.DUCK, _f(), _c({"wants_duck": false, "head_clear": true, "move_len": 0.0})).to).is_equal(T.IDLE)
	assert_str(_next(T.DUCK, _f(), _c({"wants_duck": false, "head_clear": true, "move_len": 0.9})).to).is_equal(T.WALK)


func test_run_impossible_while_ducking() -> void:
	# wants_run with wants_duck stays in duck (the controller also clears wants_run while ducking).
	assert_str(_next(T.DUCK, _f(), _c({"wants_duck": true, "wants_run": true, "move_len": 1.0})).to).is_equal(&"")


func test_jump_requires_headroom() -> void:
	var ok := _next(T.WALK, _f(Vector2.ZERO, true), _c({"headroom_ok": true}))
	assert_str(ok.to).is_equal(T.JUMP)
	assert_str(ok.effect).is_equal(T.FX_GROUND_JUMP)
	var bump := _next(T.IDLE, _f(Vector2.ZERO, true), _c({"headroom_ok": false}))
	assert_str(bump.to).is_equal(&"")
	assert_str(bump.effect).is_equal(T.FX_BUMP)


func test_duck_to_jump_stands_first_only_with_clearance() -> void:
	var t := _next(T.DUCK, _f(Vector2.ZERO, true), _c({"wants_duck": true, "head_clear": true}))
	assert_str(t.to).is_equal(T.JUMP)
	assert_str(t.effect).is_equal(T.FX_STAND_UP)
	var low := _next(T.DUCK, _f(Vector2.ZERO, true), _c({"wants_duck": true, "head_clear": false}))
	assert_str(low.to).is_equal(&"")
	assert_str(low.effect).is_equal(T.FX_LOW_CEILING)


func test_coyote_keeps_grounded_then_falls() -> void:
	assert_str(_next(T.WALK, _f(Vector2(0, -1)), _c({"on_floor": false, "coyote_left": 0.05, "move_len": 1.0})).to).is_equal(&"")
	assert_str(_next(T.WALK, _f(Vector2(0, -1)), _c({"on_floor": false, "coyote_left": 0.0, "move_len": 1.0})).to).is_equal(T.FALL)


func test_coyote_jump_is_a_ground_jump() -> void:
	var t := _next(T.WALK, _f(Vector2.ZERO, true), _c({"on_floor": false, "coyote_left": 0.05}))
	assert_str(t.effect).is_equal(T.FX_GROUND_JUMP)
	var t2 := _next(T.FALL, _f(Vector2.ZERO, true), _c({"on_floor": false, "coyote_left": 0.05, "air_jumps_left": 1}))
	assert_str(t2.effect).is_equal(T.FX_GROUND_JUMP)


func test_exactly_one_air_jump() -> void:
	var first := _next(T.JUMP, _f(Vector2.ZERO, true), _c({"on_floor": false, "vertical_velocity": 3.0, "air_jumps_left": 1}))
	assert_str(first.to).is_equal(T.JUMP)
	assert_str(first.effect).is_equal(T.FX_AIR_JUMP)
	var second := _next(T.JUMP, _f(Vector2.ZERO, true), _c({"on_floor": false, "vertical_velocity": 3.0, "air_jumps_left": 0}))
	assert_str(second.to).is_equal(&"")
	assert_str(second.effect).is_equal(T.FX_BUFFER)
	var falling := _next(T.FALL, _f(Vector2.ZERO, true), _c({"on_floor": false, "air_jumps_left": 0}))
	assert_str(falling.effect).is_equal(T.FX_BUFFER)


func test_jump_becomes_fall_at_apex_and_on_ceiling() -> void:
	assert_str(_next(T.JUMP, _f(), _c({"on_floor": false, "vertical_velocity": 0.0})).to).is_equal(T.FALL)
	var ceil := _next(T.JUMP, _f(), _c({"on_floor": false, "vertical_velocity": 4.0, "ceiling_hit": true}))
	assert_str(ceil.to).is_equal(T.FALL)
	assert_str(ceil.effect).is_equal(T.FX_CEILING)


func test_landing_and_buffered_jump() -> void:
	assert_str(_next(T.FALL, _f(), _c({"on_floor": true, "move_len": 0.0})).to).is_equal(T.IDLE)
	assert_str(_next(T.FALL, _f(), _c({"on_floor": true, "move_len": 0.7})).to).is_equal(T.WALK)
	var buffered := _next(T.FALL, _f(), _c({"on_floor": true, "jump_buffered": true}))
	assert_str(buffered.to).is_equal(T.JUMP)
	assert_str(buffered.effect).is_equal(T.FX_GROUND_JUMP)


func test_soft_landing_above_4m() -> void:
	assert_str(_next(T.FALL, _f(), _c({"on_floor": true, "fall_height": 4.0})).effect).is_equal(T.FX_LAND)
	assert_str(_next(T.FALL, _f(), _c({"on_floor": true, "fall_height": 4.1})).effect).is_equal(T.FX_SOFT_LAND)


func test_auto_jump_only_when_ready_and_moving() -> void:
	assert_str(_next(T.WALK, _f(), _c({"move_len": 1.0, "auto_jump_ready": true})).to).is_equal(T.JUMP)
	assert_str(_next(T.RUN, _f(), _c({"move_len": 1.0, "auto_jump_ready": true, "wants_run": true})).to).is_equal(T.JUMP)
	assert_str(_next(T.DUCK, _f(), _c({"wants_duck": true, "auto_jump_ready": true})).to).is_equal(&"")
	assert_str(_next(T.IDLE, _f(), _c({"auto_jump_ready": true})).to).is_equal(&"")


func test_airborne_never_enters_grounded_or_action_states_midair() -> void:
	for s in [T.JUMP, T.FALL]:
		for wants in [{"wants_duck": true}, {"wants_run": true, "move_len": 1.0}]:
			var c := _c(wants)
			c.on_floor = false
			c.vertical_velocity = -1.0
			var to := _next(s, _f(Vector2(0, -1)), c).to
			assert_bool(to in [&"", T.FALL, T.JUMP]).override_failure_message("%s -> %s" % [s, to]).is_true()


func test_exhaustion_preempts_grounded_and_waits_for_landing() -> void:
	assert_str(_next(T.WALK, _f(), _c({"exhaustion_pending": true})).to).is_equal(T.SLEEP)
	assert_str(_next(T.FALL, _f(), _c({"exhaustion_pending": true, "on_floor": false})).to).is_equal(&"")
	assert_str(_next(T.FALL, _f(), _c({"exhaustion_pending": true, "on_floor": true})).to).is_equal(T.SLEEP)
