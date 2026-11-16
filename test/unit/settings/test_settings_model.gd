# P1.27: settings defaults, round trip, unknown and mistyped keys.
extends GdUnitTestSuite


func test_defaults_match_spec_5_10() -> void:
	var m := SettingsModel.new()
	assert_str(m.get_value("input", "run_mode")).is_equal("toggle")
	assert_str(m.get_value("input", "duck_mode")).is_equal("toggle")
	assert_bool(m.get_value("input", "jump_auto")).is_true()
	assert_bool(m.get_value("input", "invert_y")).is_false()
	assert_float(m.get_value("input", "sensitivity")).is_equal(1.0)
	assert_int(m.get_value("input", "glyph_override")).is_equal(-1)


func test_round_trip() -> void:
	var m := SettingsModel.new()
	m.set_value("input", "run_mode", "hold")
	m.set_value("input", "rebinds", {"jump": [{"type": "joy_button", "button": 0}]})
	var m2 := SettingsModel.new()
	m2.from_dict(m.to_dict())
	assert_dict(m2.to_dict()).is_equal(m.to_dict())


func test_unknown_keys_ignored() -> void:
	var m := SettingsModel.new()
	assert_bool(m.set_value("input", "nope", 1)).is_false()
	m.from_dict({"input": {"nope": 1}, "weird": {"x": 2}})
	assert_dict(m.to_dict()).is_equal(SettingsModel.DEFAULTS)


func test_wrong_type_rejected_int_accepted_for_float() -> void:
	var m := SettingsModel.new()
	assert_bool(m.set_value("input", "jump_auto", "yes")).is_false()
	assert_bool(m.get_value("input", "jump_auto")).is_true()
	assert_bool(m.set_value("input", "sensitivity", 2)).is_true()


func test_reset_restores_defaults() -> void:
	var m := SettingsModel.new()
	m.set_value("input", "invert_y", true)
	m.reset()
	assert_bool(m.get_value("input", "invert_y")).is_false()
