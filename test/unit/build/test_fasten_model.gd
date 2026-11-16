# P3.16: fastening (spec 2.7).
extends GdUnitTestSuite

const ORIGIN := Vector3(0, 0, 0)
var socks: Array[Vector3] = [Vector3(0, 0, -2), Vector3(1, 0, -2), Vector3(0, 1, -2), Vector3(3, 0, -2)]


func _m(fastener: StringName, hits: int, hold := false, progress: Array = []) -> FastenModel:
	var m := FastenModel.new()
	m.setup(socks, fastener, hits, hold, progress)
	return m


func test_steps_count() -> void:
	assert_int(_m(BuildPieceDef.NAILS, 2).steps_total()).is_equal(8)
	assert_int(_m(BuildPieceDef.SCREWS, 1).steps_total()).is_equal(4)


func test_angle_snap_per_strength() -> void:
	for i in 3:
		var limit: float = FastenModel.ANGLES[i]
		var m := _m(BuildPieceDef.NAILS, 2)
		var just_in := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(limit - 0.2))
		var just_out := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(-(limit + 0.2)))
		assert_int(m.aim(ORIGIN, just_in, limit)).is_equal(0)
		m.current = -1
		assert_int(m.aim(ORIGIN, just_out, limit)).is_equal(-1)
	assert_float(FastenModel.ANGLES[2]).is_equal(9.0)


func test_nails_press_and_auto_advance_order() -> void:
	var m := _m(BuildPieceDef.NAILS, 2)
	m.aim(ORIGIN, Vector3(0, 0, -1), 9.0)
	assert_str(m.press()).is_equal(FastenModel.HIT)
	assert_str(m.press()).is_equal(FastenModel.SOCKET_DONE)
	assert_int(m.current).is_equal(1)   # (1,0,-2) and (0,1,-2) both 1 m away: lower index
	m.press(); m.press()
	assert_int(m.current).is_equal(2)
	m.press(); m.press()
	assert_int(m.current).is_equal(3)
	m.press()
	assert_str(m.press()).is_equal(FastenModel.DONE)
	assert_bool(m.is_done()).is_true()


func test_no_socket_in_range_does_nothing() -> void:
	var m := _m(BuildPieceDef.NAILS, 2)
	m.aim(ORIGIN, Vector3(0, 0, 1), 9.0)
	assert_str(m.press()).is_equal(FastenModel.NONE)
	assert_int(m.steps_done()).is_equal(0)


func test_screws_hold() -> void:
	var m := _m(BuildPieceDef.SCREWS, 1)
	m.aim(ORIGIN, Vector3(0, 0, -1), 9.0)
	assert_str(m.press()).is_equal(FastenModel.NONE)
	for i in 47:
		assert_str(m.hold(1.0 / 60.0)).is_equal(FastenModel.NONE)
	assert_str(m.hold(1.0 / 60.0)).is_equal(FastenModel.SOCKET_DONE)   # 48 frames = 0.8 s


func test_partial_progress_kept() -> void:
	var m := _m(BuildPieceDef.NAILS, 2, false, [2, 1, 0, 0])
	assert_int(m.steps_done()).is_equal(3)
	assert_bool(m.socket_done(0)).is_true()
	m.aim(ORIGIN, Vector3(0, 0, -1), 9.0)
	assert_int(m.current).is_equal(-1)   # socket 0 is done, others outside the angle
	assert_array(m.progress()).is_equal([2, 1, 0, 0])


func test_hold_mode_for_nails() -> void:
	var m := _m(BuildPieceDef.NAILS, 2, true)
	m.aim(ORIGIN, Vector3(0, 0, -1), 9.0)
	assert_str(m.press()).is_equal(FastenModel.NONE)
	assert_str(m.hold(0.39)).is_equal(FastenModel.NONE)
	assert_str(m.hold(0.01)).is_equal(FastenModel.HIT)
