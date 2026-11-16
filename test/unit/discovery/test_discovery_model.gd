# P2.26: geode pity, chest reveal on adjacency, chest pity, unique unlock pools, determinism.
extends GdUnitTestSuite

const CHEST := 11


func _mat(special: StringName = &"NONE", tool: StringName = ToolTypes.PICKAXE) -> VoxelMaterialDef:
	var m := VoxelMaterialDef.new()
	m.special = special
	m.preferred_tool = tool
	return m


func test_geode_pity_on_hard_voxels() -> void:
	var d := DiscoveryModel.new()
	d.geode_pity_limit = 3
	var w := FakeVoxelWorld.new()
	assert_bool(d.on_voxel_dug(_mat(), Vector3i.ZERO, w, CHEST)["extra_geode"]).is_false()
	assert_bool(d.on_voxel_dug(_mat(&"NONE", ToolTypes.SHOVEL), Vector3i.ZERO, w, CHEST)["extra_geode"]).is_false()
	assert_bool(d.on_voxel_dug(_mat(), Vector3i.ZERO, w, CHEST)["extra_geode"]).is_false()
	assert_bool(d.on_voxel_dug(_mat(), Vector3i.ZERO, w, CHEST)["extra_geode"]).is_true()
	assert_int(d.pity_geode).is_equal(0)


func test_geode_rock_resets_pity() -> void:
	var d := DiscoveryModel.new()
	d.pity_geode = 10
	d.on_voxel_dug(_mat(&"GEODE"), Vector3i.ZERO, FakeVoxelWorld.new(), CHEST)
	assert_int(d.pity_geode).is_equal(0)


func test_chest_revealed_by_adjacent_dig() -> void:
	var d := DiscoveryModel.new()
	var w := FakeVoxelWorld.new()
	w.set_voxel(Vector3i(1, 0, 0), CHEST)
	var r := d.on_voxel_dug(_mat(), Vector3i.ZERO, w, CHEST)
	assert_array(r["chest_cells"]).contains_exactly([Vector3i(1, 0, 0)])
	assert_int(w.get_voxel(Vector3i(1, 0, 0))).is_equal(0)


func test_digging_chest_block_itself() -> void:
	var r := DiscoveryModel.new().on_voxel_dug(_mat(&"CHEST"), Vector3i(2, 2, 2), FakeVoxelWorld.new(), CHEST)
	assert_array(r["chest_cells"]).contains_exactly([Vector3i(2, 2, 2)])


func test_chest_pity() -> void:
	var d := DiscoveryModel.new()
	d.chest_pity_limit = 2
	var w := FakeVoxelWorld.new()
	assert_array(d.on_voxel_dug(_mat(), Vector3i.ZERO, w, CHEST)["chest_cells"]).is_empty()
	assert_array(d.on_voxel_dug(_mat(), Vector3i(5, 0, 0), w, CHEST)["chest_cells"]).contains_exactly([Vector3i(5, 0, 0)])
	assert_int(d.pity_chest).is_equal(0)


func _table() -> TreasureTableDef:
	var t := TreasureTableDef.new()
	t.entries = [{"kind": "DYE", "weight": 1, "id_pool": ["dye_a", "dye_b"]}]
	t.fallback_coins_min = 20
	t.fallback_coins_max = 20
	return t


func test_unlocks_never_duplicate_then_coins() -> void:
	var u := UnlockModel.new()
	var rng := RngStreams.new(3)
	var seen: Array = []
	for i in 2:
		var r := DiscoveryModel.open_chest(_table(), u, rng)
		assert_str(r["kind"]).is_equal(&"DYE")
		assert_bool(seen.has(r["id"])).is_false()
		seen.append(r["id"])
		u.grant(&"DYE", r["id"])
	var last := DiscoveryModel.open_chest(_table(), u, rng)
	assert_str(last["kind"]).is_equal(&"COINS")
	assert_int(last["coins"]).is_equal(20)


func test_open_chest_deterministic() -> void:
	var t := TreasureTableDef.new()
	t.entries = [{"kind": "COINS", "weight": 1, "coins_min": 1, "coins_max": 1000}, {"kind": "STICKER", "weight": 1, "id_pool": ["s1", "s2", "s3"]}]
	var a := DiscoveryModel.open_chest(t, UnlockModel.new(), RngStreams.new(99))
	var b := DiscoveryModel.open_chest(t, UnlockModel.new(), RngStreams.new(99))
	assert_dict(a).is_equal(b)


func test_round_trip_and_unlock_model() -> void:
	var d := DiscoveryModel.new()
	d.pity_geode = 3
	d.pity_chest = 11
	var d2 := DiscoveryModel.new()
	d2.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	assert_dict(d2.to_dict()).is_equal({"pity": {"geode": 3, "chest": 11}})
	var u := UnlockModel.new()
	assert_bool(u.grant(&"STICKER", &"sticker_star")).is_true()
	assert_bool(u.grant(&"STICKER", &"sticker_star")).is_false()
	var u2 := UnlockModel.new()
	u2.from_dict(JSON.parse_string(JSON.stringify(u.to_dict())))
	assert_bool(u2.is_unlocked(&"STICKER", &"sticker_star")).is_true()
	assert_dict(u.to_dict()).is_equal({"stickers": ["sticker_star"]})
