# P1.23: plain-dictionary round trips, locked actions and conflict detection (spec 2.5).
extends GdUnitTestSuite

const IB = preload("res://scripts/input/input_bindings.gd")


func _round_trip(d: Dictionary) -> Dictionary:
	return RebindModel.dict_from_event(RebindModel.event_from_dict(d))


func test_round_trip_every_event_type() -> void:
	for d in [IB.jb(JOY_BUTTON_X), IB.ja(JOY_AXIS_LEFT_Y, -1.0), IB.ja(JOY_AXIS_TRIGGER_RIGHT, 1.0),
			IB.key(KEY_W), IB.key(KEY_R, true), IB.mb(MOUSE_BUTTON_WHEEL_UP)]:
		assert_dict(_round_trip(d)).is_equal(d)


func test_axis_sign_is_preserved_and_normalized() -> void:
	var e := RebindModel.event_from_dict({"type": "joy_axis", "axis": JOY_AXIS_LEFT_X, "value": -0.3})
	assert_float((e as InputEventJoypadMotion).axis_value).is_equal(-1.0)
	assert_str(RebindModel.input_id(IB.ja(JOY_AXIS_LEFT_X, 1.0))).is_not_equal(RebindModel.input_id(IB.ja(JOY_AXIS_LEFT_X, -1.0)))


func test_events_apply_to_all_devices() -> void:
	assert_int(RebindModel.event_from_dict(IB.jb(JOY_BUTTON_A)).device).is_equal(RebindModel.ALL_DEVICES)


func test_invalid_dict_returns_null() -> void:
	assert_object(RebindModel.event_from_dict({"type": "gesture"})).is_null()


func test_modifier_variants_are_distinct_inputs() -> void:
	assert_str(RebindModel.input_id(IB.key(KEY_R))).is_not_equal(RebindModel.input_id(IB.key(KEY_R, true)))


func test_conflict_in_same_context_is_found() -> void:
	var defs := {
		&"a": {"contexts": [IB.GAMEPLAY], "events": [IB.jb(JOY_BUTTON_A)], "deadzone": 0.5},
		&"b": {"contexts": [IB.GAMEPLAY, IB.UI], "events": [IB.jb(JOY_BUTTON_A)], "deadzone": 0.5},
	}
	var c := RebindModel.find_conflicts(defs, [])
	assert_int(c.size()).is_equal(1)
	assert_str(c[0]["context"]).is_equal(IB.GAMEPLAY)


func test_disjoint_contexts_do_not_conflict() -> void:
	var defs := {
		&"a": {"contexts": [IB.GAMEPLAY], "events": [IB.jb(JOY_BUTTON_A)], "deadzone": 0.5},
		&"b": {"contexts": [IB.INSTRUMENT], "events": [IB.jb(JOY_BUTTON_A)], "deadzone": 0.5},
	}
	assert_array(RebindModel.find_conflicts(defs, [])).is_empty()


func test_allowed_overlap_is_not_a_conflict() -> void:
	var defs := {
		&"pause_menu": {"contexts": [IB.UI], "events": [IB.key(KEY_ESCAPE)], "deadzone": 0.5},
		&"ui_cancel": {"contexts": [IB.UI], "events": [IB.key(KEY_ESCAPE)], "deadzone": 0.5},
	}
	assert_array(RebindModel.find_conflicts(defs)).is_empty()
	assert_int(RebindModel.find_conflicts(defs, []).size()).is_equal(1)


func test_validate_rebind_rejects_same_context_conflict() -> void:
	var r := RebindModel.validate_rebind(&"jump", [IB.jb(JOY_BUTTON_Y), IB.key(KEY_SPACE)], IB.definitions())
	assert_bool(r.ok).is_false()
	assert_str(r.error).is_equal(&"conflict")


func test_validate_rebind_accepts_free_input() -> void:
	var r := RebindModel.validate_rebind(&"jump", [IB.jb(JOY_BUTTON_PADDLE1), IB.key(KEY_SPACE)], IB.definitions())
	assert_bool(r.ok).override_failure_message(str(r.data)).is_true()


func test_locked_action_cannot_lose_gamepad() -> void:
	var r := RebindModel.validate_rebind(&"pause_menu", [IB.key(KEY_ESCAPE)], IB.definitions())
	assert_str(r.error).is_equal(&"locked_gamepad")


func test_unknown_action_and_invalid_event() -> void:
	assert_str(RebindModel.validate_rebind(&"nope", [], IB.definitions()).error).is_equal(&"unknown_action")
	assert_str(RebindModel.validate_rebind(&"interact", [{"type": "bogus"}], IB.definitions()).error).is_equal(&"invalid_event")
