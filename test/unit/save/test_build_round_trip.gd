# P3.16: BuildService pieces, deeds and placed blocks round-trip through JSON text.
extends GdUnitTestSuite


func test_build_round_trip() -> void:
	var a: GameSession = auto_free(GameSession.create(4))
	add_child(a)
	a.new_game()
	SceneRouter.current_zone_id = &"zone_home_meadow"
	(a.terrain.world as FakeVoxelWorld).fill(Vector3i(-14, -1, 8), Vector3i(0, -1, 20), Database.voxel_id_of(&"mat_dirt"))
	a.housing.grant_deed(&"plot_test")
	a.inventory.add(&"item_piece_wall", 1)
	a.inventory.add(&"item_piece_lamp", 1)
	a.inventory.add(&"item_dirt", 1)
	var w: String = a.build.try_place(&"piece_wall", Vector3i(-8, 0, 14), 3).data
	a.build.fasten_step(w, 0)
	var lamp: String = a.build.try_place(&"piece_lamp", Vector3i(-6, 0, 14), 1).data
	a.build.toggle_furniture(lamp)
	a.build.try_place_block(Vector3i(-10, 0, 12), &"mat_dirt")
	var d := a.to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d))
	var b: GameSession = auto_free(GameSession.create(1))
	add_child(b)
	b.from_dict(parsed)
	assert_dict(b.build.to_dict()).is_equal(a.build.to_dict())
	assert_dict(b.housing.plots_to_dict()).is_equal({"owned_plots": ["plot_test"]})
	assert_dict(b.build.occupancy).is_equal(a.build.occupancy)
	var p: Dictionary = b.build.pieces[w]
	assert_int(typeof(p["rot"])).is_equal(TYPE_INT)
	assert_int(typeof(p["fasten"][0])).is_equal(TYPE_INT)
	assert_str(p["state"]).is_equal(BuildService.LOOSE)
	assert_int(b.build.pieces[lamp]["toggle"]).is_equal(1)
	assert_int(b.build.next_uid).is_equal(a.build.next_uid)
	SceneRouter.current_zone_id = &""
