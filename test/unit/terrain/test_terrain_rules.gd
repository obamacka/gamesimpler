# P2.23: protection rules P1 to P7 in spec order (spec 9.3).
extends GdUnitTestSuite

const R = preload("res://scripts/terrain/models/terrain_rules.gd")
const BEDROCK := 12

var _w: FakeVoxelWorld
var _r: TerrainRules


func before_test() -> void:
	_w = FakeVoxelWorld.new()
	_w.fill(Vector3i(-10, -3, -10), Vector3i(10, 0, 10), 2)
	_w.fill(Vector3i(-10, -4, -10), Vector3i(10, -4, 10), BEDROCK)
	_r = TerrainRules.new(_w)
	_r.bedrock_voxel = BEDROCK
	_r.bounds_min_y = -4


func test_plain_cell_is_diggable() -> void:
	assert_str(_r.can_dig(Vector3i(3, 0, 3))).is_equal(R.OK)


func test_p1_protected_volume() -> void:
	_r.add_volume(Vector3i(0, -2, 0), Vector3i(2, 2, 2), &"TOWN")
	assert_str(_r.can_dig(Vector3i(1, 0, 1))).is_equal(R.PROTECTED)
	assert_str(_r.can_dig(Vector3i(3, 0, 3))).is_equal(R.OK)


func test_p2_bedrock_and_bounds() -> void:
	assert_str(_r.can_dig(Vector3i(0, -4, 0))).is_equal(R.BEDROCK)
	assert_str(_r.can_dig(Vector3i(0, -5, 0))).is_equal(R.BEDROCK)


func test_p3_support_under_objects_and_neighbors() -> void:
	_r.protect_support(Vector3i(5, 1, 5), "tree_1")
	assert_str(_r.can_dig(Vector3i(5, 0, 5))).is_equal(R.SUPPORTS_OBJECT)
	assert_str(_r.can_dig(Vector3i(6, 0, 4))).is_equal(R.SUPPORTS_OBJECT)
	assert_str(_r.can_dig(Vector3i(7, 0, 5))).is_equal(R.OK)
	_r.release_support("tree_1")
	assert_str(_r.can_dig(Vector3i(5, 0, 5))).is_equal(R.OK)


func test_p4_building_hook() -> void:
	_r.building_supported = func(c: Vector3i) -> bool: return c == Vector3i(2, 0, 2)
	assert_str(_r.can_dig(Vector3i(2, 0, 2))).is_equal(R.SUPPORTS_BUILDING)


func test_p5_job_site() -> void:
	_r.add_volume(Vector3i(-5, -2, -5), Vector3i(-3, 2, -3), &"JOB_SITE")
	assert_str(_r.can_dig(Vector3i(-4, 0, -4))).is_equal(R.JOB_SITE)


func test_p6_under_player() -> void:
	_r.player_feet_cell = Vector3i(1, 0, 1)
	assert_str(_r.can_dig(Vector3i(1, 0, 1))).is_equal(R.UNDER_PLAYER)


func test_p7_not_loaded_and_empty() -> void:
	_w.unloaded[Vector3i(4, 0, 4)] = true
	assert_str(_r.can_dig(Vector3i(4, 0, 4))).is_equal(R.NOT_LOADED)
	assert_str(_r.can_dig(Vector3i(4, 5, 4))).is_equal(R.EMPTY)


func test_evaluation_order_first_failure_wins() -> void:
	_r.add_volume(Vector3i(0, -2, 0), Vector3i(2, 2, 2), &"TOWN")
	_r.protect_support(Vector3i(1, 1, 1), "chest")
	_r.player_feet_cell = Vector3i(1, 0, 1)
	assert_str(_r.can_dig(Vector3i(1, 0, 1))).is_equal(R.PROTECTED)


func test_place_rules() -> void:
	assert_str(_r.can_place(Vector3i(0, 1, 0))).is_equal(R.OK)
	assert_str(_r.can_place(Vector3i(0, 0, 0))).is_equal(R.OCCUPIED)
	_r.add_volume(Vector3i(3, 1, 3), Vector3i(4, 3, 4), &"TOWN")
	assert_str(_r.can_place(Vector3i(3, 1, 3))).is_equal(R.PROTECTED)
	_r.add_volume(Vector3i(6, 1, 6), Vector3i(7, 3, 7), &"TOWN", true)
	assert_str(_r.can_place(Vector3i(6, 1, 6))).is_equal(R.OK)
	_r.player_cells = [Vector3i(-1, 1, -1)]
	_r.pet_cells = [Vector3i(-2, 1, -2)]
	assert_str(_r.can_place(Vector3i(-1, 1, -1))).is_equal(R.INSIDE_PLAYER)
	assert_str(_r.can_place(Vector3i(-2, 1, -2))).is_equal(R.INSIDE_PET)
