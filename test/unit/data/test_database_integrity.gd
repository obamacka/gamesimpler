# P2.28: content cross-references (spec 3.9, Phase 2 types).
extends GdUnitTestSuite


func test_no_validation_errors() -> void:
	var errors := Database.validate()
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_content_loaded() -> void:
	assert_int(Database.items.size()).is_greater(10)
	assert_int(Database.materials.size()).is_equal(12)
	assert_object(Database.material_by_voxel(5)).is_not_null()
	assert_str(Database.material_by_voxel(12).special).is_equal(VoxelMaterialDef.SPECIAL_BEDROCK)
	assert_int(Database.templates_in_pool(&"pool_care_exhausted").size()).is_greater_equal(1)
	assert_int(Database.stamina.base_max).is_equal(100)
	assert_array(Database.starter_tools).contains([&"item_shovel_basic", &"item_pickaxe_basic", &"item_picker_basic"])


func test_validation_catches_bad_reference() -> void:
	var bad := Database.materials[&"mat_stone"] as VoxelMaterialDef
	var old := bad.drop
	bad.drop = &"loot_missing"
	var errors := Database.validate()
	bad.drop = old
	assert_bool(errors.any(func(e): return e.contains("loot_missing"))).is_true()
