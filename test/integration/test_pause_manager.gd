# P1.28: ref-counted pause reasons and edge-only signals (spec 5.2).
extends GdUnitTestSuite

var _rec: SignalRecorder


func before_test() -> void:
	PauseManager.reset_for_tests()
	_rec = SignalRecorder.new(EventBus, [&"game_paused", &"game_resumed", &"pause_changed"])


func after_test() -> void:
	_rec.stop()
	PauseManager.reset_for_tests()


func test_first_reason_pauses_once() -> void:
	PauseManager.request_pause(&"menu")
	assert_bool(get_tree().paused).is_true()
	assert_bool(PauseManager.is_paused()).is_true()
	PauseManager.request_pause(&"transition")
	PauseManager.request_pause(&"menu")   # duplicate is idempotent
	assert_int(_rec.count(&"game_paused")).is_equal(1)
	assert_int(_rec.count(&"pause_changed")).is_equal(1)


func test_last_release_resumes_once() -> void:
	PauseManager.request_pause(&"menu")
	PauseManager.request_pause(&"transition")
	PauseManager.release_pause(&"menu")
	assert_bool(get_tree().paused).override_failure_message("still held by transition").is_true()
	assert_int(_rec.count(&"game_resumed")).is_equal(0)
	PauseManager.release_pause(&"transition")
	assert_bool(get_tree().paused).is_false()
	assert_int(_rec.count(&"game_resumed")).is_equal(1)
	assert_array(_rec.names()).contains_exactly([&"game_paused", &"pause_changed", &"game_resumed", &"pause_changed"])


func test_release_unknown_reason_is_noop() -> void:
	PauseManager.release_pause(&"never_requested")
	assert_bool(get_tree().paused).is_false()
	assert_array(_rec.records).is_empty()


func test_has_reason_and_reasons() -> void:
	PauseManager.request_pause(&"device_lost")
	assert_bool(PauseManager.has_reason(&"device_lost")).is_true()
	assert_bool(PauseManager.has_reason(&"menu")).is_false()
	assert_array(PauseManager.reasons()).contains_exactly([&"device_lost"])


func test_pause_changed_reports_state() -> void:
	PauseManager.request_pause(&"menu")
	assert_array(_rec.records[1]["args"][1]).contains_exactly([&"menu"])
	assert_bool(_rec.records[1]["args"][0]).is_true()


func test_reset_for_tests_clears_everything() -> void:
	PauseManager.request_pause(&"menu")
	PauseManager.request_pause(&"transition")
	PauseManager.reset_for_tests()
	assert_bool(get_tree().paused).is_false()
	assert_bool(PauseManager.is_paused()).is_false()
	assert_int(_rec.count(&"game_resumed")).is_equal(1)


func test_monitor_signals_on_autoload_with_gdunit() -> void:
	# Documents the required pattern: never let gdUnit4 auto-free an autoload.
	monitor_signals(EventBus, false)
	PauseManager.request_pause(&"menu")
	await assert_signal(EventBus).wait_until(500).is_emitted("game_paused")
	assert_bool(is_instance_valid(EventBus)).is_true()
