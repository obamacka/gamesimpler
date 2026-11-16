# P3.14: placement rules (spec 2.7, 1.6). Plot x 0..9, z 0..9 in zone "z"; ground at y -1.
extends GdUnitTestSuite

var ctx: PlacementValidator.PlacementContext
var world: FakeVoxelWorld


func before_test() -> void:
	world = FakeVoxelWorld.new()
	world.fill(Vector3i(-5, -1, -5), Vector3i(15, -1, 15), Database.voxel_id_of(&"mat_dirt"))
	var plot := PlotDef.new()
	plot.id = &"plot_t"
	plot.zone_id = &"z"
	plot.min_cell = Vector3i(0, -10, 0)
	plot.max_cell = Vector3i(9, 20, 9)
	ctx = PlacementValidator.PlacementContext.new()
	ctx.world = world
	ctx.zone = &"z"
	ctx.plots = [plot]


func _p(id: StringName) -> BuildPieceDef:
	return Database.pieces[id]


func _put(id: StringName, anchor: Vector3i, r: int, state: StringName, uid: String) -> void:
	ctx.pieces[uid] = {"piece_id": String(id), "state": state}
	for o in BuildGrid.occupancy(_p(id), anchor, r):
		ctx.occupancy[o["key"]] = uid


func test_rotation_matrix_single_and_multi_cell() -> void:
	var a := Vector3i(5, 0, 5)
	var sofa := [[Vector3i(5, 0, 5), Vector3i(6, 0, 5)], [Vector3i(5, 0, 5), Vector3i(5, 0, 4)],
		[Vector3i(5, 0, 5), Vector3i(4, 0, 5)], [Vector3i(5, 0, 5), Vector3i(5, 0, 6)]]
	var bed := [[Vector3i(5, 0, 5), Vector3i(5, 0, 6)], [Vector3i(5, 0, 5), Vector3i(6, 0, 5)],
		[Vector3i(5, 0, 5), Vector3i(5, 0, 4)], [Vector3i(5, 0, 5), Vector3i(4, 0, 5)]]
	for r in 4:
		assert_array(BuildGrid.cells(_p(&"piece_sofa"), a, r)).contains_exactly(sofa[r])
		assert_array(BuildGrid.cells(_p(&"piece_bed"), a, r)).contains_exactly(bed[r])
		assert_array(BuildGrid.cells(_p(&"piece_wall"), a, r)).contains_exactly([a, a + Vector3i.UP, a + Vector3i(0, 2, 0)])
	# The four wall rotations sit on the four faces of the cell: four different edges.
	var keys := {}
	for r in 4:
		keys[BuildGrid.occupancy(_p(&"piece_wall"), a, r)[0]["key"]] = true
	assert_int(keys.size()).is_equal(4)
	# Back-to-back walls on one edge collide: rot 2 in (5,0,5) == rot 0 in (5,0,6).
	assert_str(BuildGrid.edge_key(a, 2)).is_equal(BuildGrid.edge_key(a + Vector3i(0, 0, 1), 0))


func test_four_rotations_place_four_point_conversions() -> void:
	assert_vector(BuildGrid.rotate_point(Vector3(0.5, 0, 0.0), 1)).is_equal_approx(Vector3(0.0, 0, 0.5), Vector3.ONE * 0.0001)
	assert_vector(BuildGrid.rotate_point(Vector3(0.5, 0, 0.0), 2)).is_equal_approx(Vector3(0.5, 0, 1.0), Vector3.ONE * 0.0001)
	assert_vector(BuildGrid.rotate_point(Vector3(0.5, 0, 0.0), 3)).is_equal_approx(Vector3(1.0, 0, 0.5), Vector3.ONE * 0.0001)


func test_out_of_plot_by_one_cell() -> void:
	assert_bool(PlacementValidator.validate(ctx, _p(&"piece_floor"), Vector3i(9, 0, 9), 0)["ok"]).is_true()
	assert_str(PlacementValidator.validate(ctx, _p(&"piece_floor"), Vector3i(10, 0, 9), 0)["reason"]).is_equal(PlacementValidator.OUTSIDE_PLOT)
	assert_str(PlacementValidator.validate(ctx, _p(&"piece_sofa"), Vector3i(9, 0, 5), 0)["reason"]).is_equal(PlacementValidator.OUTSIDE_PLOT)


func test_missing_item() -> void:
	ctx.has_item = false
	assert_str(PlacementValidator.validate(ctx, _p(&"piece_floor"), Vector3i(1, 0, 1), 0)["reason"]).is_equal(PlacementValidator.MISSING_ITEM)


func test_overlaps() -> void:
	world.set_voxel(Vector3i(2, 0, 2), Database.voxel_id_of(&"mat_dirt"))
	assert_str(PlacementValidator.validate(ctx, _p(&"piece_chair"), Vector3i(2, 0, 2), 0)["reason"]).is_equal(PlacementValidator.OCCUPIED)
	_put(&"piece_chair", Vector3i(4, 0, 4), 0, &"FASTENED", "c1")
	assert_str(PlacementValidator.validate(ctx, _p(&"piece_table"), Vector3i(4, 0, 4), 0)["reason"]).is_equal(PlacementValidator.OCCUPIED)
	ctx.player_cells = [Vector3i(6, 0, 6), Vector3i(6, 1, 6)]
	assert_str(PlacementValidator.validate(ctx, _p(&"piece_chair"), Vector3i(6, 0, 6), 0)["reason"]).is_equal(PlacementValidator.OVERLAPS_PLAYER)
	ctx.pet_cells = [Vector3i(7, 0, 7)]
	var r := PlacementValidator.validate(ctx, _p(&"piece_chair"), Vector3i(7, 0, 7), 0)
	assert_bool(r["ok"]).is_true()
	assert_bool(r["nudge_pet"]).is_true()


func test_layers_share_a_cell() -> void:
	_put(&"piece_floor", Vector3i(3, 0, 3), 0, &"FASTENED", "f1")
	assert_bool(PlacementValidator.validate(ctx, _p(&"piece_chair"), Vector3i(3, 0, 3), 0)["ok"]).is_true()
	assert_bool(PlacementValidator.validate(ctx, _p(&"piece_wall"), Vector3i(3, 0, 3), 0)["ok"]).is_true()
	assert_str(PlacementValidator.validate(ctx, _p(&"piece_floor"), Vector3i(3, 0, 3), 0)["reason"]).is_equal(PlacementValidator.OCCUPIED)


func test_support_by_voxel_and_fastened_piece_not_loose() -> void:
	assert_bool(PlacementValidator.validate(ctx, _p(&"piece_floor"), Vector3i(1, 0, 1), 0)["ok"]).is_true()
	assert_str(PlacementValidator.validate(ctx, _p(&"piece_floor"), Vector3i(1, 1, 1), 0)["reason"]).is_equal(PlacementValidator.NO_SUPPORT)
	_put(&"piece_wall", Vector3i(5, 0, 5), 0, &"LOOSE", "w1")
	assert_str(PlacementValidator.validate(ctx, _p(&"piece_roof"), Vector3i(5, 3, 5), 0)["reason"]).is_equal(PlacementValidator.NO_SUPPORT)
	ctx.pieces["w1"]["state"] = &"FASTENED"
	assert_bool(PlacementValidator.validate(ctx, _p(&"piece_roof"), Vector3i(5, 3, 5), 0)["ok"]).is_true()
	# Furniture stands on a fastened floor slab in its own cell, not on a loose one.
	world.fill(Vector3i(0, 2, 0), Vector3i(9, 2, 9), Database.voxel_id_of(&"mat_dirt"))
	_put(&"piece_floor", Vector3i(2, 4, 2), 0, &"LOOSE", "f2")
	assert_str(PlacementValidator.validate(ctx, _p(&"piece_chair"), Vector3i(2, 4, 2), 0)["reason"]).is_equal(PlacementValidator.NO_SUPPORT)
	ctx.pieces["f2"]["state"] = &"FASTENED"
	assert_bool(PlacementValidator.validate(ctx, _p(&"piece_chair"), Vector3i(2, 4, 2), 0)["ok"]).is_true()


func test_door_leaves_three_cell_opening() -> void:
	var a := Vector3i(5, 0, 5)
	var door := _p(&"piece_wall_door")
	var opening := BuildGrid.opening_cells(door, a, 0)
	assert_array(opening).contains_exactly([a, a + Vector3i.UP, a + Vector3i(0, 2, 0)])
	var cells := BuildGrid.cells(door, a, 0)
	for c in opening:
		assert_bool(c in cells).is_false()
	_put(&"piece_wall_door", a, 0, &"FASTENED", "d1")
	assert_bool(PlacementValidator.validate(ctx, _p(&"piece_chair"), a, 0)["ok"]).is_true()   # the opening is free
