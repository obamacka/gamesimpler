# P1.23: device switching thresholds and glyph selection (spec 2.5).
extends GdUnitTestSuite

const Kind := InputDeviceModel.DeviceKind
const Glyph := InputDeviceModel.GlyphSet


func _mouse_motion(dx: float) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(dx, 0)
	return e


func _axis(value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = value
	return e


func _pad_button(device: int = 0) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A
	e.pressed = true
	e.device = device
	return e


func test_mouse_motion_threshold() -> void:
	assert_int(InputDeviceModel.classify(_mouse_motion(4.0))).is_equal(-1)
	assert_int(InputDeviceModel.classify(_mouse_motion(4.5))).is_equal(Kind.KEYBOARD_MOUSE)


func test_joypad_axis_threshold() -> void:
	assert_int(InputDeviceModel.classify(_axis(0.5))).is_equal(-1)
	assert_int(InputDeviceModel.classify(_axis(-0.6))).is_equal(Kind.GAMEPAD)


func test_keys_and_buttons_always_count() -> void:
	assert_int(InputDeviceModel.classify(InputEventKey.new())).is_equal(Kind.KEYBOARD_MOUSE)
	assert_int(InputDeviceModel.classify(InputEventMouseButton.new())).is_equal(Kind.KEYBOARD_MOUSE)
	assert_int(InputDeviceModel.classify(_pad_button())).is_equal(Kind.GAMEPAD)


func test_vendor_mapping() -> void:
	assert_int(InputDeviceModel.glyphs_for_vendor(0x054C)).is_equal(Glyph.PLAYSTATION)
	assert_int(InputDeviceModel.glyphs_for_vendor(0x045E)).is_equal(Glyph.XBOX)
	assert_int(InputDeviceModel.glyphs_for_vendor(0x057E)).is_equal(Glyph.NINTENDO)
	assert_int(InputDeviceModel.glyphs_for_vendor(0x1234)).is_equal(Glyph.XBOX)
	assert_int(InputDeviceModel.glyphs_for_vendor(0)).is_equal(Glyph.XBOX)


func test_feed_switches_and_reports_changes() -> void:
	var m := InputDeviceModel.new()
	assert_int(m.current_glyphs()).is_equal(Glyph.KBM)
	assert_bool(m.feed(_pad_button(2), 0x054C)).is_true()
	assert_int(m.kind).is_equal(Kind.GAMEPAD)
	assert_int(m.current_glyphs()).is_equal(Glyph.PLAYSTATION)
	assert_int(m.active_joypad).is_equal(2)
	assert_bool(m.feed(_pad_button(2), 0x054C)).override_failure_message("same device again is not a change").is_false()
	assert_bool(m.feed(_mouse_motion(2.0))).override_failure_message("tiny mouse motion ignored").is_false()
	assert_bool(m.feed(InputEventKey.new())).is_true()
	assert_int(m.current_glyphs()).is_equal(Glyph.KBM)


func test_override_wins_for_gamepads_only() -> void:
	var m := InputDeviceModel.new()
	m.glyph_override = Glyph.NINTENDO
	m.feed(_pad_button(), 0x054C)
	assert_int(m.current_glyphs()).is_equal(Glyph.NINTENDO)
	m.feed(InputEventKey.new())
	assert_int(m.current_glyphs()).is_equal(Glyph.KBM)
