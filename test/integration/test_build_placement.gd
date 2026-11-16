# P3.17: Build placement on a FakeVoxelWorld plot (spec 2.7, 4.4, 9.3 P4, 4.2.1).
extends GdUnitTestSuite

var h: Phase2Harness
var _rec: SignalRecorder


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	BuildFixture.setup(h)
	h.session.inventory.add(&"item_piece_floor", 3)
	h.session.inventory.add(&"item_piece_wall", 2)
	h.session.inventory.add(&"item_dirt", 4)
	h.place(Vector3(-7.5, 0, 12.5))
	h.aim_at_sky()
	await h.frames(4)
	_rec = SignalRecorder.new(EventBus, [&"ghost_changed", &"piece_placed", &"block_placed", &"build_mode_changed"])


func after_test() -> void:
	_rec.stop()
	h.stop()
	await get_tree().process_frame


func _ghosts() -> Array:
	return _rec.records.filter(func(r): return r["name"] == &"ghost_changed").map(func(r): return r["args"])


func test_build_needs_owned_plot() -> void:
	h.place(Vector3(0.5, 0, 0.5))   # outside every owned plot
	await h.frames(3)
	await BuildFixture.enter_build(h)
	assert_str(h.player.machine.current_id).is_not_equal(&"build")
	h.place(Vector3(-7.5, 0, 12.5))
	await h.frames(3)
	await BuildFixture.enter_build(h)
	assert_str(h.player.machine.current_id).is_equal(&"build")
	assert_int(_rec.count(&"build_mode_changed")).is_equal(1)


func test_ghost_states_and_place_consumes_item() -> void:
	await BuildFixture.enter_build(h)
	assert_str(h.player.build_ctl.model.selected["id"]).is_equal(&"piece_floor")
	BuildFixture.aim_at_top(h, Vector3i(-8, -1, 15))
	await h.frames(3)
	assert_str(h.player.build_ctl.ghost.state).is_equal(&"snapped")   # magnetic ground socket
	h.place(Vector3(-3.5, 0, 13.5))
	await h.frames(2)
	BuildFixture.aim_at_top(h, Vector3i(-2, -1, 15))   # one cell outside the plot (max x -3)
	await h.frames(3)
	assert_str(h.player.build_ctl.ghost.state).is_equal(&"invalid")
	assert_str(h.player.build_ctl.ghost.reason).is_equal(PlacementValidator.OUTSIDE_PLOT)
	h.place(Vector3(-7.5, 0, 12.5))
	await h.frames(2)
	BuildFixture.aim_at_top(h, Vector3i(-8, -1, 15))
	await h.frames(3)
	h.press("use_pressed")
	await h.frames(3)
	var placed := _rec.records.filter(func(r): return r["name"] == &"piece_placed")
	assert_int(placed.size()).is_equal(1)
	assert_array(placed[0]["args"].slice(1)).contains_exactly([&"piece_floor", Vector3i(-8, 0, 15)])
	assert_int(h.session.inventory.count(&"item_piece_floor")).is_equal(2)
	var states := _ghosts().map(func(a): return a[0])
	assert_array(states).contains([&"snapped", &"invalid"])
	await h.frames(3)
	var pv: Dictionary = h.player.build_ctl.preview
	assert_bool(pv["snapped"]).is_true()   # aiming at the new floor offers the next tile on its nearest edge
	assert_vector(pv["cell"]).is_equal(Vector3i(-8, 0, 14))
	h.session.inventory.add(&"item_piece_chair", 1)
	h.player.build_ctl.model.selected = {"kind": &"piece", "id": &"piece_floor"}
	assert_str(h.session.build.validate(&"piece_floor", Vector3i(-8, 0, 15), 0)["reason"]).is_equal(PlacementValidator.OCCUPIED)


func test_loose_piece_does_not_support() -> void:
	h.session.inventory.add(&"item_piece_roof", 1)
	var w: String = h.session.build.try_place(&"piece_wall", Vector3i(-8, 0, 15), 0).data
	assert_str(h.session.build.validate(&"piece_roof", Vector3i(-8, 3, 15), 0)["reason"]).is_equal(PlacementValidator.NO_SUPPORT)
	for i in 4:
		h.session.build.fasten_step(w, i)
		h.session.build.fasten_step(w, i)
	assert_bool(h.session.build.validate(&"piece_roof", Vector3i(-8, 3, 15), 0)["ok"]).is_true()


func test_dig_under_fastened_piece_refused() -> void:
	BuildFixture.place_fastened(h, &"piece_floor", Vector3i(-8, 0, 15), 0)
	var shovel := h.session.toolbelt.model.tool_data(ToolTypes.SHOVEL)
	assert_str(h.session.terrain.hit_voxel(Vector3i(-8, -1, 15), shovel)["result"]).is_equal(TerrainRules.SUPPORTS_BUILDING)
	assert_int(h.world.get_voxel(Vector3i(-8, -1, 15))).is_equal(h.vid(&"mat_grass"))


func test_air_pillar_placement() -> void:
	await BuildFixture.enter_build(h)
	h.player.build_ctl.model.selected = {"kind": &"block", "id": &"mat_dirt"}
	h.press("jump_pressed")
	var n := 0
	while h.player.global_position.y < 1.2 and n < 60:
		await h.frames(1)
		n += 1
	assert_bool(h.player.current_state().is_airborne()).is_true()
	BuildFixture.aim_at_top(h, Vector3i(-8, -1, 12))
	h.press("use_pressed")
	await h.frames(2)
	assert_int(h.world.get_voxel(Vector3i(-8, 0, 12))).is_equal(h.vid(&"mat_dirt"))
	assert_int(_rec.count(&"block_placed")).is_equal(1)
	n = 0
	while not h.player.is_on_floor() and n < 120:
		await h.frames(1)
		n += 1
	await h.frames(2)
	assert_str(h.player.machine.current_id).is_equal(&"build")   # landing returns to Build
