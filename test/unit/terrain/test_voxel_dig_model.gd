# P2.23: hits per material and tool, wrong-tool multiplier, tier, partial damage reset.
extends GdUnitTestSuite


func _mat(hits: int, tool: StringName, tier: int = 1) -> VoxelMaterialDef:
	var m := VoxelMaterialDef.new()
	m.hits = hits
	m.preferred_tool = tool
	m.hardness_tier = tier
	return m


func _tool(t: StringName, tier: int = 1, power: int = 1) -> ToolData:
	var d := ToolData.new()
	d.tool_type = t
	d.tier = tier
	d.power = power
	return d


func test_preferred_tool_hits() -> void:
	var m := VoxelDigModel.new()
	var stone := _mat(3, ToolTypes.PICKAXE)
	var pick := _tool(ToolTypes.PICKAXE)
	assert_str(m.hit(Vector3i.ZERO, stone, pick)["result"]).is_equal(VoxelDigModel.DAMAGED)
	assert_int(m.hit(Vector3i.ZERO, stone, pick)["hits_left"]).is_equal(1)
	assert_str(m.hit(Vector3i.ZERO, stone, pick)["result"]).is_equal(VoxelDigModel.DUG)
	assert_bool(m.damage.has(Vector3i.ZERO)).is_false()


func test_wrong_tool_doubles_hits() -> void:
	var dirt := _mat(2, ToolTypes.SHOVEL)
	assert_int(VoxelDigModel.hits_required(dirt, ToolTypes.PICKAXE)).is_equal(4)
	assert_int(VoxelDigModel.hits_required(dirt, ToolTypes.SHOVEL)).is_equal(2)


func test_tier_too_low_changes_nothing() -> void:
	var m := VoxelDigModel.new()
	var hard := _mat(4, ToolTypes.PICKAXE, 3)
	assert_str(m.hit(Vector3i.ONE, hard, _tool(ToolTypes.PICKAXE, 1))["result"]).is_equal(VoxelDigModel.TIER_TOO_LOW)
	assert_bool(m.damage.is_empty()).is_true()
	assert_str(m.hit(Vector3i.ONE, hard, _tool(ToolTypes.PICKAXE, 3))["result"]).is_equal(VoxelDigModel.DAMAGED)


func test_non_dig_tool_rejected() -> void:
	var m := VoxelDigModel.new()
	assert_str(m.hit(Vector3i.ONE, _mat(2, ToolTypes.SHOVEL), _tool(ToolTypes.AXE))["result"]).is_equal(VoxelDigModel.NOT_A_DIG_TOOL)
	assert_str(m.hit(Vector3i.ONE, _mat(2, ToolTypes.SHOVEL), null)["result"]).is_equal(VoxelDigModel.NOT_A_DIG_TOOL)


func test_daily_reset_and_round_trip() -> void:
	var m := VoxelDigModel.new()
	m.hit(Vector3i(12, 4, -7), _mat(3, ToolTypes.PICKAXE), _tool(ToolTypes.PICKAXE))
	var d := m.to_dict()
	assert_dict(d).is_equal({"12,4,-7": 1})
	var m2 := VoxelDigModel.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_int(m2.damage[Vector3i(12, 4, -7)]).is_equal(1)
	assert_int(typeof(m2.damage[Vector3i(12, 4, -7)])).is_equal(TYPE_INT)
	m2.daily_reset()
	assert_bool(m2.damage.is_empty()).is_true()


func test_loot_roller_is_deterministic() -> void:
	var t := LootTableDef.new()
	t.rolls = 3
	t.guaranteed = [{"item": "item_wood", "qty": 2}]
	t.entries = [{"item": "item_wood", "min": 0, "max": 2, "weight": 1}, {"item": "coins", "min": 1, "max": 5, "weight": 1}]
	var a := LootRoller.roll(t, RngStreams.new(7))
	var b := LootRoller.roll(t, RngStreams.new(7))
	assert_array(a).is_equal(b)
	assert_str(a[0]["item"]).is_equal(&"item_wood")
	assert_int(a[0]["qty"]).is_greater_equal(2)
