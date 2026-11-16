# P1.26: jump kinematics and timers (spec 1.4) and the auto-jump rule.
extends GdUnitTestSuite

const CAPSULE_MARGIN := 0.05


func _model() -> JumpModel:
	var m := JumpModel.new()
	m.configure(preload("res://resources/config/jump_config.tres"))
	return m


func test_first_jump_apex_clears_one_voxel() -> void:
	var m := _model()
	var apex := JumpModel.apex_height(m.jump_velocity, m.gravity)
	assert_float(apex).is_equal_approx(1.30, 0.01)
	assert_bool(apex > 1.0 + CAPSULE_MARGIN).is_true()


func test_double_jump_total_clears_two_voxels() -> void:
	var m := _model()
	var total := JumpModel.apex_height(m.jump_velocity, m.gravity) + JumpModel.apex_height(m.double_jump_velocity, m.gravity)
	assert_float(JumpModel.apex_height(m.double_jump_velocity, m.gravity)).is_equal_approx(1.20, 0.01)
	assert_bool(total > 2.0 + CAPSULE_MARGIN).override_failure_message("total %f" % total).is_true()


func test_velocity_for_height_inverts_apex() -> void:
	assert_float(JumpModel.velocity_for_height(JumpModel.apex_height(7.9, 24.0), 24.0)).is_equal_approx(7.9, 0.0001)


func test_fall_speed_capped() -> void:
	var m := _model()
	var vy := 0.0
	for i in 300:
		vy = m.apply_gravity(vy, 1.0 / 60.0)
	assert_float(vy).is_equal(-20.0)


func test_coyote_window() -> void:
	var m := _model()
	m.left_floor_without_jump()
	m.tick(0.1)
	assert_bool(m.coyote_left > 0.0).is_true()
	m.tick(0.03)
	assert_float(m.coyote_left).is_equal(0.0)


func test_buffer_window() -> void:
	var m := _model()
	m.buffer_press()
	m.tick(0.14)
	assert_bool(m.is_buffered()).is_true()
	m.tick(0.02)
	assert_bool(m.is_buffered()).is_false()


func test_air_jumps_reset_only_on_landing() -> void:
	var m := _model()
	m.consume_ground_jump()
	assert_bool(m.can_air_jump()).is_true()
	assert_float(m.consume_air_jump()).is_equal(m.double_jump_velocity)
	assert_bool(m.can_air_jump()).is_false()
	m.tick(1.0)
	assert_bool(m.can_air_jump()).is_false()
	m.landed()
	assert_bool(m.can_air_jump()).is_true()


func test_walking_off_ledge_keeps_double_jump() -> void:
	var m := _model()
	m.left_floor_without_jump()
	assert_bool(m.can_air_jump()).is_true()


func test_ground_jump_clears_coyote_and_buffer() -> void:
	var m := _model()
	m.left_floor_without_jump()
	m.buffer_press()
	assert_float(m.consume_ground_jump()).is_equal(m.jump_velocity)
	assert_float(m.coyote_left).is_equal(0.0)
	assert_bool(m.is_buffered()).is_false()


func test_ledge_model_requires_every_condition() -> void:
	var ok := [true, true, false, true, true, true, 0.3, 0.5]
	assert_bool(LedgeModel.should_auto_jump.callv(ok)).is_true()
	var flips := {0: false, 1: false, 2: true, 3: false, 4: false, 5: false, 6: 0.29, 7: 0.49}
	for i in flips:
		var args := ok.duplicate()
		args[i] = flips[i]
		assert_bool(LedgeModel.should_auto_jump.callv(args)).override_failure_message("arg %d" % i).is_false()
