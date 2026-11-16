# P2B.13: spec 10.4 farm tool rules, row by row. FarmService.aim_for builds the aim; the
# ToolSelectionModel decides the tool. Garden plot cells x 4..11, z -4..3 in zone_home_meadow.
extends GdUnitTestSuite

const GRASS := Vector3i(5, -1, 0)

var s: GameSession
var world: FakeVoxelWorld


func before_test() -> void:
	world = FakeVoxelWorld.new()
	s = GameSession.create(11, world)
	add_child(s)
	s.new_game()
	SceneRouter.current_zone_id = &"zone_home_meadow"
	world.fill(Vector3i(-2, -3, -6), Vector3i(16, -2, 6), Database.voxel_id_of(&"mat_dirt"))
	world.fill(Vector3i(-2, -1, -6), Vector3i(16, -1, 6), Database.voxel_id_of(&"mat_grass"))
	s.inventory.add(&"item_seed_carrot", 5)   # backpack slot 0 = hotbar slot 0


func after_test() -> void:
	SceneRouter.current_zone_id = &""
	s.queue_free()


func _seed_selected() -> StringName:
	s.hotbar.select(0)
	return s.hotbar.selected_item_id(s.inventory.model)


func _nothing_selected() -> StringName:
	s.hotbar.select(5)
	return s.hotbar.selected_item_id(s.inventory.model)


## Runs the selection model on `aim` long enough to pass the debounce; returns the events.
func _select(aim: Dictionary) -> Array:
	var model := ToolSelectionModel.new(s.toolbelt.model)
	var events: Array = []
	for i in 20:
		events.append_array(model.update(1.0 / 60.0, aim, [], false))
	return events


func _equips(events: Array) -> Array:
	return events.filter(func(e): return e["type"] == &"equip").map(func(e): return [e["tool"], e["target_kind"]])


func test_seed_on_farmable_soil_tills_with_hoe() -> void:
	var aim := s.farm.aim_for(GRASS, _seed_selected())
	assert_str(aim["target_kind"]).is_equal(&"till")
	assert_str(aim["tool"]).is_equal(ToolTypes.HOE)
	assert_str(aim["farm"]["seed"]).is_equal(&"item_seed_carrot")
	assert_array(_equips(_select(aim))).contains_exactly([[ToolTypes.HOE, &"till"]])


func test_no_seed_on_farmable_soil_uses_plain_voxel_rule() -> void:
	assert_dict(s.farm.aim_for(GRASS, _nothing_selected())).is_empty()


func test_manual_hoe_tills_without_seed() -> void:
	s.toolbelt.model.equip(ToolTypes.HOE)
	var aim := s.farm.aim_for(GRASS, _nothing_selected())
	assert_str(aim["target_kind"]).is_equal(&"till")
	assert_str(aim["farm"]["seed"]).is_equal(&"")


func test_seed_outside_plot_is_blocked() -> void:
	var aim := s.farm.aim_for(Vector3i(14, -1, 0), _seed_selected())
	assert_str(aim["blocked"]).is_equal(FarmModel.NOT_FARMABLE)
	assert_array(_equips(_select(aim))).is_empty()


func test_empty_farmland_with_seed_plants_without_tool() -> void:
	assert_bool(s.farm.try_till(GRASS).ok).is_true()
	s.farm.try_water(GRASS)
	var aim := s.farm.aim_for(GRASS, _seed_selected())
	assert_str(aim["target_kind"]).is_equal(&"plant")
	assert_str(aim["tool"]).is_equal(&"")
	assert_array(_equips(_select(aim))).is_empty()


func test_unwatered_farmland_or_crop_uses_can() -> void:
	s.farm.try_till(GRASS)
	var aim := s.farm.aim_for(GRASS, _nothing_selected())
	assert_str(aim["target_kind"]).is_equal(&"water")
	assert_array(_equips(_select(aim))).contains_exactly([[ToolTypes.WATERING_CAN, &"water"]])
	s.farm.try_plant(GRASS, &"item_seed_carrot")
	assert_str(s.farm.aim_for(GRASS, _seed_selected())["target_kind"]).is_equal(&"water")   # crop present: seed does not matter


func test_watered_growing_crop_falls_back_to_voxel_rule() -> void:
	s.farm.try_till(GRASS, &"item_seed_carrot")
	s.farm.try_water(GRASS)
	assert_dict(s.farm.aim_for(GRASS, _nothing_selected())).is_empty()
	assert_str(s.terrain.can_dig(GRASS)).is_equal(TerrainRules.SUPPORTS_OBJECT)


func test_ripe_crop_harvests_without_tool() -> void:
	s.farm.try_till(GRASS, &"item_seed_carrot")
	var k := FarmModel.key(&"zone_home_meadow", GRASS + Vector3i.UP)
	s.farm.model.crops[k]["growth_days"] = (Database.crops[&"crop_carrot"] as CropDef).days_to_ripe()
	var aim := s.farm.aim_for(GRASS, _nothing_selected())
	assert_str(aim["target_kind"]).is_equal(&"harvest")
	assert_str(aim["tool"]).is_equal(&"")
	var t: FarmActionTarget = auto_free(FarmActionTarget.new())
	assert_object(t.spec_for(null, false, false)).is_null()   # an unconfigured target offers nothing
	t.configure(aim["farm"], Vector3.ZERO)
	var rows := PromptModel.rows({}, &"", t.spec_for(null, false, false), null)
	assert_array(rows.map(func(r): return r["text"])).contains_exactly(["Harvest"])


func test_well_refill_row() -> void:
	var aim := {"key": "well", "kind": &"zone", "tool": ToolTypes.WATERING_CAN, "target_kind": &"refill", "tier_required": 0, "blocked": &""}
	assert_array(_equips(_select(aim))).contains_exactly([[ToolTypes.WATERING_CAN, &"refill"]])


func test_empty_can_badge() -> void:
	s.farm.try_till(GRASS)
	s.farm.model.can_water = 0
	var aim := s.farm.aim_for(GRASS, _nothing_selected())
	assert_str(aim["badge"]).is_equal(FarmModel.EMPTY_CAN)
	var events := _select(aim)
	assert_array(_equips(events)).contains_exactly([[ToolTypes.WATERING_CAN, &"water"]])
	var prompts := events.filter(func(e): return e["type"] == &"prompt").map(func(e): return e["state"])
	assert_array(prompts).contains([FarmModel.EMPTY_CAN])
	assert_str(PromptModel.rows(aim, &"", null, null)[0]["text"]).contains("refill")
