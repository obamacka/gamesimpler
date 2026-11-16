# Generic FSM: one active state, enter/exit exactly once per transition (spec 4.2 invariants).
extends GdUnitTestSuite


class CountingState:
	extends State
	var enters := 0
	var exits := 0
	var last_msg := {}

	func enter(msg: Dictionary = {}) -> void:
		enters += 1
		last_msg = msg

	func exit() -> void:
		exits += 1


func _machine() -> StateMachine:
	var sm := StateMachine.new()
	for n in ["Idle", "Walk"]:
		var s := CountingState.new()
		s.name = n
		sm.add_child(s)
	add_child(sm)
	return auto_free(sm)


func test_initial_state_entered_once() -> void:
	var sm := _machine()
	assert_str(sm.current_id).is_equal(&"idle")
	assert_int((sm.states[&"idle"] as CountingState).enters).is_equal(1)


func test_transition_calls_exit_and_enter_once_and_emits() -> void:
	var sm := _machine()
	var rec := SignalRecorder.new(sm, [&"transitioned"])
	sm.transition_to(&"walk", {"effect": &"x"})
	var idle: CountingState = sm.states[&"idle"]
	var walk: CountingState = sm.states[&"walk"]
	assert_int(idle.exits).is_equal(1)
	assert_int(walk.enters).is_equal(1)
	assert_dict(walk.last_msg).is_equal({"effect": &"x"})
	assert_array(rec.records[0]["args"]).contains_exactly([&"idle", &"walk"])
	rec.stop()


func test_reentering_same_state_is_allowed() -> void:
	var sm := _machine()
	sm.transition_to(&"idle")
	var idle: CountingState = sm.states[&"idle"]
	assert_int(idle.enters).is_equal(2)
	assert_int(idle.exits).is_equal(1)
