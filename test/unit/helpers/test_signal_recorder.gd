extends GdUnitTestSuite


class Emitter:
	extends RefCounted
	signal none
	signal one(a: int)
	signal two(a: int, b: String)


var _emitter: Emitter
var _recorder: SignalRecorder


func before_test() -> void:
	_emitter = Emitter.new()
	_recorder = SignalRecorder.new(_emitter, [&"none", &"one", &"two"])


func after_test() -> void:
	_recorder.stop()


func test_records_emissions_in_order_with_args() -> void:
	_emitter.two.emit(1, "x")
	_emitter.none.emit()
	_emitter.one.emit(7)

	assert_array(_recorder.names()).contains_exactly([&"two", &"none", &"one"])
	assert_array(_recorder.records[0]["args"]).contains_exactly([1, "x"])
	assert_array(_recorder.records[1]["args"]).is_empty()
	assert_array(_recorder.records[2]["args"]).contains_exactly([7])


func test_counts_per_signal() -> void:
	_emitter.one.emit(1)
	_emitter.one.emit(2)
	_emitter.none.emit()

	assert_int(_recorder.count(&"one")).is_equal(2)
	assert_int(_recorder.count(&"none")).is_equal(1)
	assert_int(_recorder.count(&"two")).is_equal(0)


func test_records_physics_frame() -> void:
	_emitter.none.emit()
	assert_int(_recorder.records[0]["physics_frame"]).is_equal(Engine.get_physics_frames())


func test_stop_disconnects_and_is_idempotent() -> void:
	_recorder.stop()
	_recorder.stop()
	_emitter.one.emit(1)
	assert_array(_recorder.records).is_empty()


func test_clear_resets_records() -> void:
	_emitter.none.emit()
	_recorder.clear()
	assert_array(_recorder.records).is_empty()


func test_test_session_keeps_seed() -> void:
	assert_int(TestSession.new_for_tests(42).rng_seed).is_equal(42)
	assert_int(TestSession.new_for_tests().rng_seed).is_equal(TestSession.DEFAULT_SEED)


func test_physics_wait_advances_physics_frames() -> void:
	var start := Engine.get_physics_frames()
	await PhysicsWait.frames(get_tree(), 3)
	assert_int(Engine.get_physics_frames() - start).is_greater_equal(3)
