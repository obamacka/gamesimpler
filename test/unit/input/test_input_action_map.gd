# P1.22: the project input map matches InputBindings and the spec 2.2 to 2.4 tables.
extends GdUnitTestSuite

var _defs: Dictionary


func before() -> void:
	_defs = InputBindings.definitions()


func _ids(events: Array) -> Array:
	var ids: Array = []
	for e in events:
		ids.append(RebindModel.input_id(e if e is Dictionary else RebindModel.dict_from_event(e)))
	ids.sort()
	return ids


func test_every_defined_action_exists_in_project_input_map() -> void:
	for action in _defs:
		assert_bool(InputMap.has_action(action)).override_failure_message("missing action %s; run scripts/tools/generate_input_map.gd" % action).is_true()


func test_project_events_match_bindings_table() -> void:
	for action in _defs:
		var expected := _ids(_defs[action]["events"])
		var actual := _ids(InputMap.action_get_events(action))
		assert_array(actual).override_failure_message("%s events drifted: %s vs %s" % [action, actual, expected]).is_equal(expected)


func test_project_deadzones_match_bindings_table() -> void:
	for action in _defs:
		assert_float(InputMap.action_get_deadzone(action)).override_failure_message("%s deadzone" % action).is_equal_approx(_defs[action]["deadzone"], 0.001)


func test_spec_2_2_gamepad_buttons() -> void:
	# Independent of the table: the spec's button assignments (D2: A jump, X/Y interact).
	var expected := {
		&"jump": "joy_button:%d" % JOY_BUTTON_A,
		&"duck": "joy_button:%d" % JOY_BUTTON_B,
		&"interact": "joy_button:%d" % JOY_BUTTON_X,
		&"interact_alt": "joy_button:%d" % JOY_BUTTON_Y,
		&"run": "joy_button:%d" % JOY_BUTTON_LEFT_STICK,
		&"hotbar_next": "joy_button:%d" % JOY_BUTTON_RIGHT_SHOULDER,
		&"hotbar_prev": "joy_button:%d" % JOY_BUTTON_LEFT_SHOULDER,
		&"build_mode": "joy_button:%d" % JOY_BUTTON_DPAD_UP,
		&"emote_wheel": "joy_button:%d" % JOY_BUTTON_DPAD_LEFT,
		&"pet_call": "joy_button:%d" % JOY_BUTTON_DPAD_RIGHT,
		&"quick_eat": "joy_button:%d" % JOY_BUTTON_DPAD_DOWN,
		&"camera_reset": "joy_button:%d" % JOY_BUTTON_RIGHT_STICK,
		&"pause_menu": "joy_button:%d" % JOY_BUTTON_START,
		&"use_tool": "joy_axis:%d:+" % JOY_AXIS_TRIGGER_RIGHT,
		&"use_alt": "joy_axis:%d:+" % JOY_AXIS_TRIGGER_LEFT,
		&"move_forward": "joy_axis:%d:-" % JOY_AXIS_LEFT_Y,
		&"look_right": "joy_axis:%d:+" % JOY_AXIS_RIGHT_X,
	}
	for action in expected:
		assert_array(_ids(InputMap.action_get_events(action))).override_failure_message("%s missing %s" % [action, expected[action]]).contains([expected[action]])
	assert_array(_ids(InputMap.action_get_events(&"open_inventory"))).contains(["joy_button:%d" % JOY_BUTTON_BACK, "joy_button:%d" % JOY_BUTTON_TOUCHPAD])


func test_spec_deadzones_for_sticks_and_triggers() -> void:
	for a in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		assert_float(InputMap.action_get_deadzone(a)).is_equal_approx(0.2, 0.001)
	for a in [&"use_tool", &"use_alt", &"note_7", &"note_8", &"ui_page_next", &"ui_page_prev"]:
		assert_float(InputMap.action_get_deadzone(a)).is_equal_approx(0.5, 0.001)


func test_ui_actions_have_explicit_gamepad_and_keyboard_events() -> void:
	for a in [&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		var events: Array = _defs[a]["events"]
		var pad := events.any(func(e): return RebindModel.is_gamepad(e))
		var kb := events.any(func(e): return e["type"] == "key")
		assert_bool(pad and kb).override_failure_message(a).is_true()
	assert_array(_ids(InputMap.action_get_events(&"ui_accept"))).contains(["joy_button:%d" % JOY_BUTTON_A])
	assert_array(_ids(InputMap.action_get_events(&"ui_cancel"))).contains(["joy_button:%d" % JOY_BUTTON_B])


func test_gameplay_actions_have_gamepad_and_kbm_events() -> void:
	for action in _defs:
		var contexts: Array = _defs[action]["contexts"]
		if not (InputBindings.GAMEPLAY in contexts):
			continue
		var events: Array = _defs[action]["events"]
		var pad := events.any(func(e): return RebindModel.is_gamepad(e))
		var kbm := events.any(func(e): return not RebindModel.is_gamepad(e))
		if String(action).begins_with("hotbar_") and String(action).right(1).is_valid_int():
			assert_bool(pad).override_failure_message("%s should be keyboard-only (spec 2.2)" % action).is_false()
			continue
		assert_bool(pad).override_failure_message("%s has no gamepad event" % action).is_true()
		if String(action).begins_with("look_"):
			continue   # mouse look is the raw mouse delta, not an action (spec 2.1)
		assert_bool(kbm).override_failure_message("%s has no keyboard/mouse event" % action).is_true()


func test_locked_actions_keep_gamepad_events() -> void:
	for action in InputBindings.LOCKED_GAMEPAD:
		var events: Array = _defs[action]["events"]
		assert_bool(events.any(func(e): return RebindModel.is_gamepad(e))).override_failure_message(action).is_true()


func test_no_physical_input_bound_twice_within_a_context() -> void:
	var conflicts := RebindModel.find_conflicts(_defs)
	assert_array(conflicts).override_failure_message("conflicts: %s" % [conflicts]).is_empty()


func test_modifier_shadowed_keys_use_exact_match() -> void:
	# Same base key with and without Shift in one context fires both actions unless read with exact_match.
	var base := {}   # "ctx:keycode" -> Array[action]
	for action in _defs:
		for e in _defs[action]["events"]:
			if e["type"] != "key":
				continue
			for ctx in _defs[action]["contexts"]:
				var k := "%s:%d" % [ctx, e["physical_keycode"]]
				if not base.has(k):
					base[k] = {}
				base[k][action] = e.get("shift", false)
	for k in base:
		var actions: Dictionary = base[k]
		if actions.size() < 2:
			continue
		var mods := actions.values()
		if mods.has(true) and mods.has(false):
			for a in actions:
				assert_bool(a in InputBindings.EXACT_MATCH).override_failure_message("%s shares %s with a modifier variant; add it to EXACT_MATCH" % [a, k]).is_true()
