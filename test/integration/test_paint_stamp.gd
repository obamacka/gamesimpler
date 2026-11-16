# P6.17: painting sets the instance shader parameter; stamps create Decals; the ninth stamp
# is refused; undo restores; everything survives save and load.
extends GdUnitTestSuite

const DIR := "user://test_tmp/decor"
const WALL := Vector3i(-8, 0, 15)

var h: Phase2Harness
var uid := ""


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	SaveService.base_dir = DIR
	BuildFixture.setup(h)
	uid = BuildFixture.place_fastened(h, &"piece_wall", WALL, 0)
	h.place(Vector3(-7.5, 0, 13))
	h.aim_at_sky()
	await h.frames(3)


func after_test() -> void:
	VoxelPersistence.remove_dir(DIR)
	h.stop()
	await get_tree().process_frame


func _view() -> PieceView:
	return SceneRouter.current_zone.get_node("BuildView").views[uid]


func _aim_wall() -> void:
	BuildFixture.aim_at_point(h, Vector3(-7.5, 1.2, 15.0))
	await h.frames(3)


func test_paint_through_the_paint_tool() -> void:
	await BuildFixture.enter_build(h)
	h.press("build_tool_next_pressed")
	await h.frames(2)
	assert_str(h.player.build_ctl.model.tool).is_equal(BuildModel.PAINT)
	h.player.build_ctl.model.dye = &"dye_berry"
	await _aim_wall()
	h.press("use_pressed")
	await h.frames(3)
	assert_str(h.session.build.pieces[uid]["paint"]["PRIMARY"]).is_equal("dye_berry")
	var c: Color = _view().meshes[0].get_instance_shader_parameter(&"primary_color")
	assert_that(c).is_equal(Database.dyes[&"dye_berry"].color)
	h.press("interact_pressed")   # eyedropper copies the region's dye
	h.player.build_ctl.model.dye = &"dye_sky"
	await h.frames(1)
	h.press("interact_pressed")
	await h.frames(2)
	assert_str(h.player.build_ctl.model.dye).is_equal(&"dye_berry")
	h.press("undo_pressed")
	await h.frames(2)
	assert_bool(h.session.build.pieces[uid]["paint"].has("PRIMARY")).is_false()


func test_stamps_cap_undo_and_save() -> void:
	await BuildFixture.enter_build(h)
	h.press("build_tool_next_pressed")
	await h.frames(1)
	h.press("build_tool_next_pressed")
	await h.frames(2)
	assert_str(h.player.build_ctl.model.tool).is_equal(BuildModel.STAMP)
	h.player.build_ctl.model.sticker = &"sticker_flower"
	await _aim_wall()
	for i in 9:
		h.press("use_pressed")
		await h.frames(2)
	assert_int(h.session.build.pieces[uid]["stamps"].size()).is_equal(StampModel.CAP)
	await h.frames(2)
	assert_int(_view().decals.size()).is_equal(8)
	assert_bool(_view().decals.all(func(d): return d is Decal)).is_true()
	h.press("undo_pressed")
	await h.frames(2)
	assert_int(h.session.build.pieces[uid]["stamps"].size()).is_equal(7)
	h.session.build.try_paint(uid, &"PRIMARY", &"dye_moss")
	var before: Dictionary = h.session.build.to_dict()
	assert_bool((await SaveService.save_slot(1, h.session)).ok).is_true()
	h.session.from_dict(SaveService.load_slot(1).data["data"])
	assert_dict(h.session.build.to_dict()).is_equal(before)
	EventBus.build_changed.emit(&"zone_home_meadow")
	await h.frames(2)
	assert_int(_view().decals.size()).is_equal(7)
	assert_that(_view().meshes[0].get_instance_shader_parameter(&"primary_color")).is_equal(Database.dyes[&"dye_moss"].color)


func test_decor_refused_on_unowned_or_locked() -> void:
	assert_str(h.session.build.try_paint(uid, &"PRIMARY", &"dye_amethyst").error).is_equal(PaintModel.LOCKED)
	assert_str(h.session.build.try_stamp(uid, &"sticker_crown", Vector3.ZERO, Vector3.UP, 0, "M").error).is_equal(StampModel.LOCKED)
