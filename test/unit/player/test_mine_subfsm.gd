# P2.27: Mine sub-FSM timing and exits (spec 4.3).
extends GdUnitTestSuite

const DT := 1.0 / 60.0


func _run_until(m: MineModel, held: bool, valid: bool, exhausted: bool, max_frames: int = 200) -> Array:
	var ev: Array = []
	for i in max_frames:
		var e := m.tick(DT, held, valid, exhausted)
		if e != &"":
			ev.append(e)
		if m.is_done():
			break
	return ev


func test_strikes_repeat_while_held() -> void:
	var m := MineModel.new()
	m.start(0.5)
	var strikes := 0
	for i in 90:   # 1.5 s
		if m.tick(DT, true, true, false) == &"strike":
			strikes += 1
			m.report_strike(false)
	assert_int(strikes).is_equal(3)


func test_release_ends_after_recover() -> void:
	var m := MineModel.new()
	m.start(0.5)
	assert_array(_run_until(m, false, true, false)).contains_exactly([&"strike", &"done"])


func test_lost_target_ends() -> void:
	var m := MineModel.new()
	m.start(0.5)
	assert_array(_run_until(m, true, false, false)).contains_exactly([&"done"])


func test_exhaustion_ends_after_strike_lands() -> void:
	var m := MineModel.new()
	m.start(0.5)
	assert_array(_run_until(m, true, true, true)).contains_exactly([&"strike", &"done"])


func test_retarget_after_destroy() -> void:
	var m := MineModel.new()
	m.start(0.5)
	for i in 15:
		if m.tick(DT, true, true, false) == &"strike":
			m.report_strike(true)
	var ev := _run_until(m, true, true, false, 40)
	assert_bool(ev.has(&"strike")).override_failure_message("retargets to the next valid voxel").is_true()
	var m2 := MineModel.new()
	m2.start(0.5)
	for i in 15:
		if m2.tick(DT, true, true, false) == &"strike":
			m2.report_strike(true)
	assert_array(_run_until(m2, true, false, false)).contains_exactly([&"done"])
