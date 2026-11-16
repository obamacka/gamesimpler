# P2.23: DDA raycast matches VoxelTool semantics (cell hit, previous empty cell, max distance).
extends GdUnitTestSuite


func _world() -> FakeVoxelWorld:
	var w := FakeVoxelWorld.new()
	w.fill(Vector3i(-5, 0, -5), Vector3i(5, 0, 5), 2)   # floor at y = 0
	return w


func test_straight_down_hits_floor() -> void:
	var hit := _world().raycast(Vector3(0.5, 5.0, 0.5), Vector3.DOWN, 10.0)
	assert_vector(hit["cell"]).is_equal(Vector3i(0, 0, 0))
	assert_vector(hit["prev_cell"]).is_equal(Vector3i(0, 1, 0))
	assert_int(hit["voxel_id"]).is_equal(2)
	assert_float(hit["distance"]).is_equal_approx(4.0, 0.001)


func test_axis_aligned_horizontal() -> void:
	var w := FakeVoxelWorld.new()
	w.set_voxel(Vector3i(3, 1, 0), 5)
	var hit := w.raycast(Vector3(0.5, 1.5, 0.5), Vector3.RIGHT, 10.0)
	assert_vector(hit["cell"]).is_equal(Vector3i(3, 1, 0))
	assert_vector(hit["prev_cell"]).is_equal(Vector3i(2, 1, 0))


func test_diagonal() -> void:
	var w := FakeVoxelWorld.new()
	w.set_voxel(Vector3i(2, 2, 2), 5)
	var hit := w.raycast(Vector3(0.5, 0.5, 0.5), Vector3(1, 1, 1), 10.0)
	assert_vector(hit["cell"]).is_equal(Vector3i(2, 2, 2))


func test_negative_coordinates() -> void:
	var w := FakeVoxelWorld.new()
	w.set_voxel(Vector3i(-3, 0, -1), 5)
	var hit := w.raycast(Vector3(-0.5, 0.5, -0.5), Vector3(-1, 0, -0.2), 10.0)
	assert_vector(hit["cell"]).is_equal(Vector3i(-3, 0, -1))


func test_max_distance_and_miss() -> void:
	var w := _world()
	assert_dict(w.raycast(Vector3(0.5, 5.0, 0.5), Vector3.DOWN, 3.5)).is_empty()
	assert_dict(w.raycast(Vector3(0.5, 5.0, 0.5), Vector3.UP, 50.0)).is_empty()
	assert_dict(w.raycast(Vector3(0.5, 5.0, 0.5), Vector3.ZERO, 50.0)).is_empty()


func test_set_air_removes() -> void:
	var w := _world()
	w.set_voxel(Vector3i(0, 0, 0), 0)
	assert_int(w.get_voxel(Vector3i(0, 0, 0))).is_equal(0)
	assert_bool(w.cells.has(Vector3i(0, 0, 0))).is_false()
