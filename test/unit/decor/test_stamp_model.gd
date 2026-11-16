# P6.12: stamps (cap 8, transforms, removal).
extends GdUnitTestSuite


func test_cap_and_checks() -> void:
	var wall: BuildPieceDef = Database.pieces[&"piece_wall"]
	var stamps: Array = []
	for i in 8:
		assert_str(StampModel.check(wall, stamps, true, true)).is_equal(&"")
		stamps.append(StampModel.make(&"sticker_star", Vector3(i * 0.1, 1, 0), Vector3.BACK, 0, "S"))
	assert_str(StampModel.check(wall, stamps, true, true)).is_equal(StampModel.FULL)
	assert_str(StampModel.check(Database.pieces[&"piece_lamp"], [], true, true)).is_equal(StampModel.NOT_STAMPABLE)
	assert_str(StampModel.check(wall, [], true, false)).is_equal(StampModel.LOCKED)
	assert_str(StampModel.check(wall, [], false, true)).is_equal(PaintModel.NOT_OWNED)


func test_make_snaps_rotation_and_size() -> void:
	var s := StampModel.make(&"sticker_star", Vector3(0.1234, 1.5, -0.4), Vector3.UP, 100, "XL")
	assert_int(s["rot_deg"]).is_equal(90)
	assert_str(s["size"]).is_equal("M")
	assert_float(s["pos"][0]).is_equal(0.123)


func test_local_space_round_trip_at_each_rotation() -> void:
	var cell := Vector3i(4, 0, -2)
	var world := Vector3(4.7, 1.2, -1.9)
	for r in 4:
		var local := StampModel.to_local(world, cell, r)
		assert_vector(StampModel.to_world(local, cell, r)).is_equal_approx(world, Vector3.ONE * 0.0001)


func test_nearest_removal() -> void:
	var stamps := [StampModel.make(&"a", Vector3(0, 1, 0), Vector3.UP, 0, "M"), StampModel.make(&"b", Vector3(0.5, 1, 0), Vector3.UP, 0, "M")]
	assert_int(StampModel.nearest(stamps, Vector3(0.4, 1, 0))).is_equal(1)
	assert_int(StampModel.nearest(stamps, Vector3(3, 1, 0))).is_equal(-1)
