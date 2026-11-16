# P6.12: decor undo ring buffer of 20; service undo restores paint and stamps; cleared on zone
# change.
extends GdUnitTestSuite


func test_ring_buffer() -> void:
	var u := DecorUndoModel.new()
	for i in 25:
		u.push({"i": i})
	assert_int(u.size()).is_equal(20)
	assert_int(u.pop()["i"]).is_equal(24)
	u.clear()
	assert_dict(u.pop()).is_empty()


func test_service_undo_and_zone_clear() -> void:
	var s: GameSession = auto_free(GameSession.create(3))
	add_child(s)
	s.new_game()
	SceneRouter.current_zone_id = &"zone_home_meadow"
	(s.terrain.world as FakeVoxelWorld).fill(Vector3i(-14, -1, 8), Vector3i(0, -1, 20), Database.voxel_id_of(&"mat_dirt"))
	s.housing.grant_deed(&"plot_test")
	s.inventory.add(&"item_piece_wall", 1)
	var uid: String = s.build.try_place(&"piece_wall", Vector3i(-8, 0, 14), 0).data
	assert_bool(s.build.try_paint(uid, &"PRIMARY", &"dye_sky").ok).is_true()
	assert_bool(s.build.try_paint(uid, &"PRIMARY", &"dye_moss").ok).is_true()
	assert_bool(s.build.try_stamp(uid, &"sticker_flower", Vector3(0, 1, 0.15), Vector3.BACK, 0, "M").ok).is_true()
	assert_bool(s.build.try_remove_stamp(uid, Vector3(0, 1, 0.15)).ok).is_true()
	s.build.undo_decor()   # the stamp comes back
	assert_int(s.build.pieces[uid]["stamps"].size()).is_equal(1)
	s.build.undo_decor()   # the stamp is gone again
	assert_int(s.build.pieces[uid]["stamps"].size()).is_equal(0)
	s.build.undo_decor()
	assert_str(s.build.pieces[uid]["paint"]["PRIMARY"]).is_equal("dye_sky")
	s.build.undo_decor()
	assert_bool(s.build.pieces[uid]["paint"].has("PRIMARY")).is_false()
	s.build.try_paint(uid, &"PRIMARY", &"dye_sky")
	EventBus.zone_unloading.emit(&"zone_home_meadow")
	assert_str(s.build.undo_decor().error).is_equal(&"nothing_to_undo")
	SceneRouter.current_zone_id = &""
