# P2.28: content cross-references (spec 3.9, Phase 2 types).
extends GdUnitTestSuite


func test_no_validation_errors() -> void:
	var errors := Database.validate()
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_content_loaded() -> void:
	assert_int(Database.items.size()).is_greater(10)
	assert_int(Database.materials.size()).is_equal(13)
	assert_object(Database.material_by_voxel(5)).is_not_null()
	assert_str(Database.material_by_voxel(12).special).is_equal(VoxelMaterialDef.SPECIAL_BEDROCK)
	assert_int(Database.templates_in_pool(&"pool_care_exhausted").size()).is_greater_equal(1)
	assert_int(Database.stamina.base_max).is_equal(100)
	assert_array(Database.starter_tools).contains([&"item_shovel_basic", &"item_pickaxe_basic", &"item_picker_basic"])


func test_farm_content_loaded() -> void:
	assert_int(Database.crops.size()).is_equal(6)
	assert_str(Database.material_by_voxel(13).id).is_equal(&"mat_farmland")
	assert_str(Database.item(&"item_seed_carrot").seed_crop).is_equal(&"crop_carrot")
	var plot: PlotDef = Database.plots[&"plot_starter_garden"]
	assert_bool(plot.owned_from_start).is_true()
	assert_bool(plot.contains(&"zone_home_meadow", Vector3i(4, 0, 0))).is_true()
	assert_bool(plot.contains(&"zone_home_meadow", Vector3i(12, 0, 0))).is_false()
	assert_int(Database.farm.can_capacity).is_equal(20)
	assert_array(Database.starter_tools).contains([&"item_hoe_basic", &"item_watering_can_basic"])


func test_validation_catches_bad_crop() -> void:
	var c: CropDef = Database.crops[&"crop_carrot"]
	var old := c.harvest_item_id
	c.harvest_item_id = &"item_missing"
	var errors := Database.validate()
	c.harvest_item_id = old
	assert_bool(errors.any(func(e): return e.contains("crop_carrot"))).is_true()


func test_validation_catches_bad_reference() -> void:
	var bad := Database.materials[&"mat_stone"] as VoxelMaterialDef
	var old := bad.drop
	bad.drop = &"loot_missing"
	var errors := Database.validate()
	bad.drop = old
	assert_bool(errors.any(func(e): return e.contains("loot_missing"))).is_true()
