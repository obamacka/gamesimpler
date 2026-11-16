# P4.23: rebind_capture applies, refuses conflicts and locked unbinding, persists to
# settings.cfg (in user://test_tmp/).
extends GdUnitTestSuite

const DIR := "user://test_tmp"
const PATH := "user://test_tmp/settings.cfg"

var h: Phase2Harness
var _old_path: String


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	DirAccess.make_dir_recursive_absolute(DIR)
	_old_path = Settings.path
	Settings.path = PATH


func after_test() -> void:
	Settings.path = _old_path
	Settings.model.reset()
	InputService.reset_to_defaults()
	DirAccess.remove_absolute(PATH)
	h.stop()
	await get_tree().process_frame


func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = true
	return e


func test_apply_new_key_and_persist() -> void:
	var m: MenuBase = h.menus.push(&"rebind_capture", {"action": &"jump"})
	var r: Result = m.apply_event(_key(KEY_J))
	assert_bool(r.ok).override_failure_message(str(r.error)).is_true()
	assert_bool(InputMap.action_has_event(&"jump", _key(KEY_J))).is_true()
	assert_bool(InputMap.action_get_events(&"jump").any(func(e): return e is InputEventJoypadButton)).is_true()   # pad binding kept
	var cfg := ConfigFile.new()
	assert_int(cfg.load(PATH)).is_equal(OK)
	var saved: Dictionary = cfg.get_value("input", "rebinds")
	assert_bool(saved.has("jump")).is_true()
	assert_bool((saved["jump"] as Array).any(func(d): return d.get("physical_keycode", 0) == KEY_J)).is_true()
	h.menus.close_all()


func test_same_context_conflict_refused() -> void:
	var interact_key: InputEvent = InputMap.action_get_events(&"interact").filter(func(e): return e is InputEventKey)[0]
	var m: MenuBase = h.menus.push(&"rebind_capture", {"action": &"jump"})
	var r: Result = m.apply_event(_key(interact_key.physical_keycode))
	assert_str(r.error).is_equal(&"conflict")
	assert_bool(InputMap.action_has_event(&"jump", interact_key)).is_false()
	h.menus.close_all()


func test_locked_gamepad_actions_cannot_be_unbound() -> void:
	var defs: Dictionary = load("res://ui/menus/rebind_capture.gd").current_definitions()
	var kb_only: Array = (defs[&"jump"]["events"] as Array).filter(func(d): return not RebindModel.is_gamepad(d))
	assert_str(RebindModel.validate_rebind(&"jump", kb_only, defs).error).is_equal(&"locked_gamepad")


func test_settings_menu_persists_options() -> void:
	var m: MenuBase = h.menus.push(&"settings")
	assert_bool(m.set_option("accessibility", "text_scale", 1.5)).is_true()
	m.cycle("assist", "snap_strength")
	assert_str(Settings.get_value("assist", "snap_strength")).is_equal("low")
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	assert_float(cfg.get_value("accessibility", "text_scale")).is_equal(1.5)
	h.menus.close_all()
