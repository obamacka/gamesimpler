# P3.16: natural block placement and owned-plot instant removal (spec 4.4, D17), and P4
# support protection going live once a piece exists (terrain/test_terrain_rules_support).
extends GdUnitTestSuite

const IN_PLOT := Vector3i(-8, 0, 14)
const OUTSIDE := Vector3i(0, 0, 0)

var s: GameSession
var world: FakeVoxelWorld


func before_test() -> void:
	world = FakeVoxelWorld.new()
	s = GameSession.create(3, world)
	add_child(s)
	s.new_game()
	SceneRouter.current_zone_id = &"zone_home_meadow"
	world.fill(Vector3i(-14, -1, -2), Vector3i(2, -1, 20), Database.voxel_id_of(&"mat_dirt"))
	s.housing.grant_deed(&"plot_test")
	s.build.bind_zone(&"zone_home_meadow", auto_free(Node3D.new()))
	s.inventory.add(&"item_dirt", 5)


func after_test() -> void:
	SceneRouter.current_zone_id = &""
	s.queue_free()


func test_place_consumes_and_sets_voxel() -> void:
	var placed := [0]
	EventBus.block_placed.connect(func(_c, _m): placed[0] += 1)
	assert_bool(s.build.try_place_block(IN_PLOT, &"mat_dirt").ok).is_true()
	assert_int(world.get_voxel(IN_PLOT)).is_equal(Database.voxel_id_of(&"mat_dirt"))
	assert_int(s.inventory.count(&"item_dirt")).is_equal(4)
	assert_int(placed[0]).is_equal(1)
	assert_str(s.build.try_place_block(IN_PLOT, &"mat_dirt").error).is_equal(TerrainRules.OCCUPIED)
	assert_bool(s.build.try_place_block(OUTSIDE, &"mat_dirt").ok).is_true()   # placing is allowed anywhere legal


func test_occupancy_against_pieces_and_missing_item() -> void:
	s.inventory.add(&"item_piece_floor", 1)
	assert_bool(s.build.try_place(&"piece_floor", IN_PLOT, 0).ok).is_true()
	assert_str(s.build.try_place_block(IN_PLOT, &"mat_dirt").error).is_equal(TerrainRules.OCCUPIED)
	s.inventory.remove(&"item_dirt", 5)
	assert_str(s.build.try_place_block(IN_PLOT + Vector3i.RIGHT, &"mat_dirt").error).is_equal(PlacementValidator.MISSING_ITEM)
	assert_str(s.build.try_place_block(IN_PLOT, &"mat_bedrock").error).is_equal(BuildService.NOT_PLACEABLE)


func test_owned_plot_instant_removal_returns_item() -> void:
	s.build.try_place_block(IN_PLOT, &"mat_dirt")
	assert_bool(s.build.try_remove_block(IN_PLOT).ok).is_true()
	assert_int(world.get_voxel(IN_PLOT)).is_equal(IVoxelWorld.AIR)
	assert_int(s.inventory.count(&"item_dirt")).is_equal(5)


func test_outside_plot_requires_digging() -> void:
	s.build.try_place_block(OUTSIDE, &"mat_dirt")
	assert_str(s.build.try_remove_block(OUTSIDE).error).is_equal(BuildService.OUTSIDE_PLOT)
	assert_int(world.get_voxel(OUTSIDE)).is_not_equal(IVoxelWorld.AIR)


func test_p4_support_protection_live_once_a_piece_exists() -> void:
	var below := IN_PLOT + Vector3i.DOWN
	assert_str(s.terrain.can_dig(below)).is_equal(TerrainRules.OK)
	s.inventory.add(&"item_piece_chair", 1)
	s.build.try_place(&"piece_chair", IN_PLOT, 0)
	assert_str(s.terrain.can_dig(below)).is_equal(TerrainRules.SUPPORTS_BUILDING)
	var uid: String = s.build.pieces.keys()[0]
	s.build.try_remove(uid)
	assert_str(s.terrain.can_dig(below)).is_equal(TerrainRules.OK)


func test_remove_refused_with_dependents() -> void:
	s.inventory.add(&"item_piece_floor", 1)
	s.inventory.add(&"item_piece_chair", 1)
	var floor_uid: String = s.build.try_place(&"piece_floor", IN_PLOT, 0).data
	for i in 2:
		s.build.fasten_step(floor_uid, 0)
		s.build.fasten_step(floor_uid, 1)
	assert_str(s.build.pieces[floor_uid]["state"]).is_equal(BuildService.FASTENED)
	var chair_uid: String = s.build.try_place(&"piece_chair", IN_PLOT, 0).data
	assert_str(s.build.try_remove(floor_uid).error).is_equal(BuildService.HAS_DEPENDENTS)
	assert_bool(s.build.try_remove(chair_uid).ok).is_true()
	assert_bool(s.build.try_remove(floor_uid).ok).is_true()
	assert_int(s.inventory.count(&"item_piece_floor")).is_equal(1)
