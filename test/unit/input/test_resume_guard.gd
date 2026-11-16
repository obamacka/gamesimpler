# P1.23: resume input guard (spec 5.5) and toggle/hold activation.
extends GdUnitTestSuite


func test_presses_dropped_through_resume_frame() -> void:
	var g := ResumeGuardModel.new()
	g.arm(100, [])
	assert_bool(g.filter_pressed(&"interact", 99, true, true)).is_false()
	assert_bool(g.filter_pressed(&"interact", 100, true, true)).is_false()
	assert_bool(g.filter_pressed(&"interact", 101, true, true)).is_true()


func test_action_held_at_resume_requires_release() -> void:
	var g := ResumeGuardModel.new()
	g.arm(100, [&"jump"])
	# Still held after the resume frame: ignored.
	assert_bool(g.filter_pressed(&"jump", 105, false, true)).is_false()
	assert_bool(g.filter_held(&"jump", true)).is_false()
	# Released once.
	assert_bool(g.filter_pressed(&"jump", 106, false, false)).is_false()
	# New press counts.
	assert_bool(g.filter_pressed(&"jump", 107, true, true)).is_true()
	assert_bool(g.filter_held(&"jump", true)).is_true()


func test_jump_suppressed_after_menu_close() -> void:
	# The A press that closed a menu (pressed on the resume frame) must not jump.
	var g := ResumeGuardModel.new()
	g.arm(200, [&"jump"])
	assert_bool(g.filter_pressed(&"jump", 200, true, true)).is_false()
	assert_bool(g.filter_pressed(&"jump", 201, false, true)).is_false()


func test_unarmed_guard_passes_everything() -> void:
	var g := ResumeGuardModel.new()
	assert_bool(g.filter_pressed(&"x", 0, true, true)).is_true()
	assert_bool(g.filter_held(&"x", true)).is_true()
	assert_bool(g.is_armed()).is_false()


func test_toggle_mode() -> void:
	var t := ToggleHoldModel.new(ToggleHoldModel.TOGGLE)
	assert_bool(t.update(true, true)).is_true()
	assert_bool(t.update(false, true)).is_true()
	assert_bool(t.update(false, false)).is_true()
	assert_bool(t.update(true, true)).is_false()


func test_hold_mode() -> void:
	var t := ToggleHoldModel.new(ToggleHoldModel.HOLD)
	assert_bool(t.update(true, true)).is_true()
	assert_bool(t.update(false, true)).is_true()
	assert_bool(t.update(false, false)).is_false()
