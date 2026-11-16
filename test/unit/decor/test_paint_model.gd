# P6.12: paint rules (spec 7.2).
extends GdUnitTestSuite


func test_rules() -> void:
	var wall: BuildPieceDef = Database.pieces[&"piece_wall"]
	var inst := {"paint": {}}
	assert_str(PaintModel.check(wall, inst, &"PRIMARY", &"dye_sky", false, true)).is_equal(PaintModel.NOT_OWNED)
	assert_str(PaintModel.check(wall, inst, &"TRIM", &"dye_sky", true, true)).is_equal(PaintModel.NO_REGION)
	assert_str(PaintModel.check(wall, inst, &"PRIMARY", &"dye_sky", true, false)).is_equal(PaintModel.LOCKED)
	assert_str(PaintModel.check(wall, inst, &"PRIMARY", &"dye_sky", true, true)).is_equal(&"")
	inst["paint"]["PRIMARY"] = "dye_sky"
	assert_str(PaintModel.check(wall, inst, &"PRIMARY", &"dye_sky", true, true)).is_equal(PaintModel.SAME)
	assert_that(PaintModel.color_of(inst, &"PRIMARY")).is_equal(Database.dyes[&"dye_sky"].color)
	assert_array(PaintModel.regions(Database.pieces[&"piece_wall_door"])).is_equal([&"PRIMARY", &"TRIM"])
	assert_array(PaintModel.regions(Database.pieces[&"piece_lamp"])).is_empty()
