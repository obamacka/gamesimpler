# PA3.4, PA4.4: pet, crop, tool and block-tile data (spec 11.8 to 11.10).
extends GdUnitTestSuite


func test_crop_models_map_stages_to_growth() -> void:
	var with_models := 0
	for id in Database.crops:
		var c: CropDef = Database.crops[id]
		if not c.has_models():
			continue
		with_models += 1
		assert_int((c.models["stages"] as Array).size()).is_equal(3)
		assert_str(c.model_for(0, false)).is_equal(c.models["stages"][0])
		assert_str(c.model_for(c.stage_count() - 1, false)).is_equal(c.models["stages"][2])
		assert_str(c.model_for(0, true)).is_equal(c.models["ripe"])
		# stage models never go backwards as the crop grows
		var last := -1
		for st in c.stage_count():
			var i := (c.models["stages"] as Array).find(c.model_for(st, false))
			assert_bool(i >= last).is_true()
			last = i
	assert_int(with_models).is_equal(5)
	assert_bool(Database.crops[&"crop_cotton"].has_models()).is_false()


func test_crop_scale_fits_the_ripe_plant_and_growth_is_smaller() -> void:
	for id in Database.crops:
		var c: CropDef = Database.crops[id]
		if not c.has_models():
			continue
		var s := CropView.scale_for(c)
		var box := CropView.box_for(c)
		var sizes: Array[float] = []
		for f in (c.models["stages"] as Array) + [c.models["ripe"]]:
			var m := ModelFit.instantiate(f)
			var b := ModelFit.local_aabb(m)
			sizes.append(b.size.y * s)
			m.free()
		assert_float(sizes[3]).override_failure_message(String(id)).is_less_equal(box.size.y + 0.001)
		assert_float(sizes[0]).override_failure_message(String(id)).is_less(sizes[3])


func test_pet_species_have_models_and_model_bones() -> void:
	for id in [&"pet_dog", &"pet_cat"]:
		var sp: PetSpeciesDef = Database.pet_species[id]
		assert_bool(ResourceLoader.exists(sp.model)).is_true()
		assert_int(sp.model_yaw_deg).is_equal(90)
		var m := ModelFit.instantiate(sp.model)
		var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
		for slot in ["HEAD", "NECK", "BODY"]:
			assert_int(sk.find_bone(sp.accessory_bones[slot])).override_failure_message("%s %s" % [id, slot]).is_greater_equal(0)
		var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
		assert_bool(ap.has_animation(sp.anim_idle)).is_true()
		assert_bool(ap.has_animation(sp.anim_walk)).is_true()
		m.free()


func test_tools_with_models_and_without() -> void:
	for id in [&"item_pickaxe_basic", &"item_pickaxe_iron", &"item_shovel_basic", &"item_axe_basic", &"item_hammer_basic", &"item_hoe_basic"]:
		assert_bool(ResourceLoader.exists(Database.items[id].world_model)).override_failure_message(String(id)).is_true()
	assert_str(Database.items[&"item_pickaxe_iron"].world_model).contains("upgraded")
	assert_str(Database.items[&"item_pickaxe_basic"].world_model).not_contains("upgraded")
	for id in [&"item_watering_can_basic", &"item_picker_basic", &"item_screwdriver_basic"]:
		assert_str(Database.items[id].world_model).is_empty()


func test_every_material_has_tiles_and_an_atlas() -> void:
	for m: VoxelMaterialDef in Database.materials.values():
		assert_bool(m.tiles.is_empty()).override_failure_message(String(m.id)).is_false()
		var tex := VoxelLibraryBuilder.atlas_for(m)
		assert_object(tex).is_not_null()
		var tile := (load(VoxelLibraryBuilder.TILE_DIR + m.tile("side")) as Texture2D).get_width()
		assert_int(tex.get_width()).is_equal(tile * 3)
		assert_int(tex.get_height()).is_equal(tile)
	# grass: green top, dirt-and-grass side, dirt bottom
	var g: VoxelMaterialDef = Database.materials[&"mat_grass"]
	assert_str(g.tile("top")).is_equal("grass_top.png")
	assert_str(g.tile("side")).is_equal("dirt_grass.png")
	assert_str(g.tile("bottom")).is_equal("dirt.png")
	assert_str(Database.materials[&"mat_stone"].tile("top")).is_equal("stone.png")   # side stands in


func test_library_uses_the_atlas() -> void:
	var lib := VoxelLibraryBuilder.build()
	var cube := lib.get_model(Database.materials[&"mat_grass"].voxel_id) as VoxelBlockyModelCube
	assert_that(cube.atlas_size_in_tiles).is_equal(VoxelLibraryBuilder.ATLAS)
	assert_that(cube.get_tile(VoxelBlockyModel.SIDE_POSITIVE_Y)).is_equal(VoxelLibraryBuilder.TOP)
	assert_that(cube.get_tile(VoxelBlockyModel.SIDE_NEGATIVE_Y)).is_equal(VoxelLibraryBuilder.BOTTOM)
	assert_that(cube.get_tile(VoxelBlockyModel.SIDE_POSITIVE_X)).is_equal(VoxelLibraryBuilder.SIDE)
	var mat := cube.get_material_override(0) as StandardMaterial3D
	assert_object(mat.albedo_texture).is_not_null()
	var bed := lib.get_model(Database.materials[&"mat_bedrock"].voxel_id) as VoxelBlockyModelCube
	assert_that((bed.get_material_override(0) as StandardMaterial3D).albedo_color).is_equal(Database.materials[&"mat_bedrock"].tint)


func test_validation_catches_missing_tiles_and_crop_models() -> void:
	var m: VoxelMaterialDef = Database.materials[&"mat_sand"]
	var old: Dictionary = m.tiles
	m.tiles = {"side": "missing.png"}
	var errors := Database.validate()
	m.tiles = old
	assert_bool(errors.any(func(e): return e.contains("mat_sand tile"))).is_true()
	var c: CropDef = Database.crops[&"crop_carrot"]
	var oldm: Dictionary = c.models
	c.models = {"stages": ["res://missing.fbx", oldm["stages"][1], oldm["stages"][2]], "ripe": oldm["ripe"], "height": 0.6}
	errors = Database.validate()
	c.models = oldm
	assert_bool(errors.any(func(e): return e.contains("crop_carrot model"))).is_true()
