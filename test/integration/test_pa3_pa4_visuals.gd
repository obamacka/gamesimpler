# PA3.4, PA4.4: pets on their models, crop stage visuals, the tool in hand (spec 11.8 to 11.10).
extends GdUnitTestSuite


func _pet(species: StringName, variant: int, accessories: Dictionary = {}) -> Pet:
	var p := Pet.create(null, {"species_id": species, "color_variant": variant, "accessories": accessories})
	add_child(p)
	return auto_free(p)


func test_pet_uses_model_coloured_by_material_name() -> void:
	var p := _pet(&"pet_cat", 0)
	assert_object(p.model).is_not_null()
	assert_object(p.anim).is_not_null()
	assert_str(String(p.anim.current_animation)).is_equal(String(p.species.anim_idle))
	var coat := p.species.variants[0]
	var seen := {}
	for mi in ModelFit.mesh_instances(p.model):
		for i in mi.mesh.get_surface_count():
			var name := mi.mesh.surface_get_material(i).resource_name
			var over := mi.get_surface_override_material(i) as BaseMaterial3D
			seen[name] = over.albedo_color if over else null
	assert_that(seen["Grey"]).is_equal(coat)
	assert_that(seen["White"]).is_equal(p.species.material_colors["White"])
	# fitted into the species size box
	var b: AABB = p.model.transform * ModelFit.local_aabb(p.model)
	assert_bool(b.size.x <= p.species.size.x + 0.01 and b.size.y <= p.species.size.y + 0.01 and b.size.z <= p.species.size.z + 0.01).is_true()
	assert_float(b.size.z).is_greater(b.size.x)   # turned so the body runs along Z


func test_pet_accessory_hangs_on_the_model_bone_at_true_size() -> void:
	var p := _pet(&"pet_dog", 1, {"NECK": {"item_id": "item_petacc_bandana", "data": {}}})
	await get_tree().process_frame
	var att: BoneAttachment3D = p.attachments[&"NECK"]
	assert_str(att.bone_name).is_equal("Bone.002")
	assert_object(att.get_parent()).is_same(p.skeleton)
	var box := p.accessory_mesh(&"NECK")
	assert_object(box).is_not_null()
	assert_float(box.global_transform.basis.get_scale().x).is_equal_approx(1.0, 0.02)


func test_pet_walk_clip_and_facing() -> void:
	var p := _pet(&"pet_dog", 0)
	p.velocity = Vector3(2.0, 0, 0)
	for i in 30:
		p._update_visual(1.0 / 60.0)
	assert_str(String(p.anim.current_animation)).is_equal(String(p.species.anim_walk))
	assert_float(p.get_node("Visual").rotation.y).is_equal_approx(atan2(-2.0, 0.0), 0.05)
	p.velocity = Vector3.ZERO
	p._update_visual(1.0 / 60.0)
	assert_str(String(p.anim.current_animation)).is_equal(String(p.species.anim_idle))


func test_crop_view_stages_and_ripe_glow() -> void:
	var c: CropDef = Database.crops[&"crop_tomato"]
	var young: CropView = auto_free(CropView.new())
	add_child(young)
	young.setup(c, 0)
	assert_str(young.model.scene_file_path).is_equal(c.models["stages"][0])
	var ripe: CropView = auto_free(CropView.new())
	add_child(ripe)
	ripe.setup(c, c.days_to_ripe())
	assert_str(ripe.model.scene_file_path).is_equal(c.models["ripe"])
	for mi in ModelFit.mesh_instances(ripe.model):
		assert_object(mi.material_overlay).is_not_null()
	for mi in ModelFit.mesh_instances(young.model):
		assert_object(mi.material_overlay).is_null()
	assert_float(young.model.transform.basis.get_scale().x).is_equal_approx(ripe.model.transform.basis.get_scale().x, 0.0001)


func test_equipped_tool_shows_in_the_right_hand() -> void:
	var h := Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	var p := h.player
	h.session.toolbelt.equip(ToolTypes.PICKAXE, &"test")
	p.update_animation(null)
	assert_object(p.character.held).is_not_null()
	assert_str(p.character.held.bone_name).is_equal("hand_r")
	assert_str(p.character.held_path).is_equal(Database.items[h.session.toolbelt.model.owned[ToolTypes.PICKAXE]].world_model)
	await get_tree().process_frame
	# about 0.6 m long in the world
	var m: Node3D = p.character.held.get_child(0).get_child(0)
	var b: AABB = ModelFit.local_aabb(m)
	assert_float(b.size.y * m.global_transform.basis.get_scale().x).is_equal_approx(CharacterRig.HELD_LENGTH, 0.05)
	h.session.toolbelt.equip(ToolTypes.WATERING_CAN, &"test")
	p.update_animation(null)
	assert_object(p.character.held).is_null()   # no model for the watering can
	h.session.toolbelt.unequip(&"test")
	p.update_animation(null)
	assert_object(p.character.held).is_null()
	h.stop()
	await get_tree().process_frame
