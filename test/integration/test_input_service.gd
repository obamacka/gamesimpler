# P1.30: device change signals, glyph override, rebinding and settings persistence.
# Events are passed to InputService.handle_event directly (headless runs do not deliver them).
extends GdUnitTestSuite

const IB = preload("res://scripts/input/input_bindings.gd")
const Kind := InputDeviceModel.DeviceKind
const Glyph := InputDeviceModel.GlyphSet
const TMP_SETTINGS := "user://test_tmp/settings_test.cfg"

var _rec: SignalRecorder


func before_test() -> void:
	Settings.model.reset()
	InputService.device = InputDeviceModel.new()
	InputService.reset_to_defaults()
	_rec = SignalRecorder.new(EventBus, [&"input_device_changed"])


func after_test() -> void:
	_rec.stop()
	Settings.model.reset()
	InputService.device = InputDeviceModel.new()
	InputService.reset_to_defaults()


func _pad_button() -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A
	e.pressed = true
	e.device = 0
	return e


func test_gamepad_then_keyboard_emits_kind_and_glyphs() -> void:
	InputService.handle_event(_pad_button())
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	InputService.handle_event(key)
	assert_int(_rec.count(&"input_device_changed")).is_equal(2)
	assert_array(_rec.records[0]["args"]).contains_exactly([Kind.GAMEPAD, Glyph.XBOX])
	assert_array(_rec.records[1]["args"]).contains_exactly([Kind.KEYBOARD_MOUSE, Glyph.KBM])


func test_small_mouse_motion_does_not_switch() -> void:
	InputService.handle_event(_pad_button())
	var m := InputEventMouseMotion.new()
	m.relative = Vector2(2, 1)
	InputService.handle_event(m)
	assert_int(_rec.count(&"input_device_changed")).is_equal(1)


func test_glyph_override_setting_applies() -> void:
	InputService.handle_event(_pad_button())
	Settings.set_value("input", "glyph_override", Glyph.PLAYSTATION)
	assert_int(InputService.current_glyphs()).is_equal(Glyph.PLAYSTATION)
	assert_array(_rec.records.back()["args"]).contains_exactly([Kind.GAMEPAD, Glyph.PLAYSTATION])


func test_valid_rebind_updates_input_map_and_reset_restores() -> void:
	InputService.apply_rebinds({"jump": [IB.jb(JOY_BUTTON_PADDLE1), IB.key(KEY_SPACE)]})
	var ids: Array = InputMap.action_get_events(&"jump").map(func(e): return RebindModel.input_id(RebindModel.dict_from_event(e)))
	assert_array(ids).contains_exactly_in_any_order(["joy_button:%d" % JOY_BUTTON_PADDLE1, "key:%d" % KEY_SPACE])
	InputService.reset_to_defaults()
	ids = InputMap.action_get_events(&"jump").map(func(e): return RebindModel.input_id(RebindModel.dict_from_event(e)))
	assert_array(ids).contains("joy_button:%d" % JOY_BUTTON_A)


func test_conflicting_rebind_is_ignored() -> void:
	InputService.apply_rebinds({"jump": [IB.jb(JOY_BUTTON_Y)]})   # Y is interact_alt in GAMEPLAY
	var ids: Array = InputMap.action_get_events(&"jump").map(func(e): return RebindModel.input_id(RebindModel.dict_from_event(e)))
	assert_array(ids).contains("joy_button:%d" % JOY_BUTTON_A)
	assert_array(ids).not_contains(["joy_button:%d" % JOY_BUTTON_Y])


func test_settings_persist_rebinds_as_plain_dicts() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_tmp"))
	var rebinds := {"jump": [IB.jb(JOY_BUTTON_PADDLE1), IB.key(KEY_SPACE)]}
	Settings.set_value("input", "rebinds", rebinds)
	assert_int(Settings.save_to(TMP_SETTINGS)).is_equal(OK)
	var text := FileAccess.get_file_as_string(TMP_SETTINGS)
	assert_bool(text.contains("InputEvent")).override_failure_message("settings must not contain serialized InputEvents").is_false()
	Settings.model.reset()
	Settings.load_from(TMP_SETTINGS)
	assert_dict(Settings.get_value("input", "rebinds")).is_equal(rebinds)
	Settings.path = Settings.DEFAULT_PATH
