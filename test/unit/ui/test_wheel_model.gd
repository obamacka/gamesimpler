# P5.17: wheel angle to slot, dead zone, neutral release cancels (spec 4.8).
extends GdUnitTestSuite


func test_angles() -> void:
	assert_int(WheelModel.slot_for(Vector2(0, -1))).is_equal(0)    # up
	assert_int(WheelModel.slot_for(Vector2(1, 0))).is_equal(2)     # right
	assert_int(WheelModel.slot_for(Vector2(0, 1))).is_equal(4)     # down
	assert_int(WheelModel.slot_for(Vector2(-1, 0))).is_equal(6)    # left
	assert_int(WheelModel.slot_for(Vector2(0.7, -0.7))).is_equal(1)
	assert_int(WheelModel.slot_for(Vector2(-0.7, -0.7))).is_equal(7)
	assert_int(WheelModel.slot_for(Vector2(0.38, -0.92))).is_equal(0)   # 22 deg: still slot 0
	assert_int(WheelModel.slot_for(Vector2(0.4, -0.917))).is_equal(1)   # 23.6 deg: slot 1


func test_dead_zone_and_release() -> void:
	var m := WheelModel.new()
	assert_int(WheelModel.slot_for(Vector2(0.59, 0))).is_equal(-1)
	assert_int(m.hover(Vector2(1, 0))).is_equal(2)
	assert_int(m.hover(Vector2(0.1, 0))).is_equal(2)   # hover keeps the last slot inside the dead zone
	assert_int(m.release(Vector2.ZERO)).is_equal(-1)   # neutral release cancels
	m.hover(Vector2(0, 1))
	assert_int(m.release(Vector2(0, 1))).is_equal(4)
