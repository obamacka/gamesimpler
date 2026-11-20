# PA2.7: character composition (spec 11.5, 11.6), player size (spec 1.4) and NPC looks.
extends GdUnitTestSuite


func _rig(body: StringName, hair: String = "Hair_SimpleParted") -> CharacterRig:
	var r: CharacterRig = auto_free(CharacterRig.new())
	add_child(r)
	r.setup(body, hair)
	return r


func _names(r: CharacterRig, slot: StringName) -> Array:
	return (r.slot_nodes.get(slot, []) as Array).map(func(n): return String(n.name))


## Height of the Head bone in world space at the current pose.
func _head_y(r: CharacterRig) -> float:
	var sk := r.skeleton
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))).origin.y


func test_head_cut_keeps_only_head_and_neck_triangles() -> void:
	for body in [CharacterRig.MALE, CharacterRig.FEMALE]:
		var r := _rig(body)
		var head := r.skeleton.get_node("Head") as MeshInstance3D
		var mesh := head.mesh as ArrayMesh
		var full := 0
		var src: Node = (load(CharacterRig.ROOT + CharacterRig.HEAD_SRC[body]) as PackedScene).instantiate()
		for c in src.get_node("Armature/Skeleton3D").get_children():
			if c is MeshInstance3D:
				full = maxi(full, CharacterRig._vertex_count(c.mesh))
		src.free()
		var kept := 0
		for s in mesh.get_surface_count():
			kept += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		assert_int(kept).is_greater(100)
		# every kept vertex is weighted mostly to Head or neck_01
		var keep := {}
		for i in head.skin.get_bind_count():
			if String(head.skin.get_bind_name(i)) in CharacterRig.HEAD_BONES:
				keep[i] = true
		var arr := mesh.surface_get_arrays(0)
		var vb: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var vw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := vb.size() / (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		for t in (arr[Mesh.ARRAY_INDEX] as PackedInt32Array):
			var best := -1.0
			var bone := -1
			for k in per:
				if vw[t * per + k] > best:
					best = vw[t * per + k]
					bone = vb[t * per + k]
			assert_bool(keep.has(bone)).is_true()
		# the head is a small part of the body mesh's bounds: above the shoulders only
		assert_float(mesh.custom_aabb.position.y).is_greater(1.3)
		assert_float(mesh.custom_aabb.end.y).is_between(1.6, 1.95)


func test_rig_is_player_height_and_faces_minus_z() -> void:
	for body in [CharacterRig.MALE, CharacterRig.FEMALE]:
		var r := _rig(body)
		await get_tree().process_frame
		# Head bone sits a head's height below the 1.7 m top.
		assert_float(_head_y(r)).is_between(1.4, 1.6)
		assert_float(r.rotation.y).is_equal_approx(PI, 0.001)
		assert_str(r.current_clip).is_equal(CharacterAnimModel.IDLE)


func test_empty_slots_show_the_base_layer() -> void:
	var r := _rig(CharacterRig.MALE)
	assert_array(_names(r, &"TOP")).contains_exactly(["Male_Peasant_Body", "Male_Peasant_Arms"])
	assert_array(_names(r, &"BOTTOM")).contains_exactly(["Male_Peasant_Legs"])
	assert_array(_names(r, &"FEET")).contains_exactly(["Male_Peasant_Feet"])
	assert_array(_names(r, &"HEAD")).is_empty()
	var mi: MeshInstance3D = r.slot_nodes[&"TOP"][0]
	var cloth := -1
	for i in mi.mesh.get_surface_count():
		if mi.get_surface_override_material(i):
			cloth = i
	assert_int(cloth).is_greater_equal(0)
	var tex: Texture2D = (mi.get_surface_override_material(cloth) as BaseMaterial3D).albedo_texture
	assert_str(tex.resource_path).ends_with(CharacterRig.BASE_TEXTURE)


func test_worn_parts_replace_the_base_and_dye_the_cloth_only() -> void:
	var r := _rig(CharacterRig.FEMALE, "Hair_Long")
	var slots := {&"TOP": {"item_id": &"item_outfit_raincoat", "data": {"dye": "dye_berry"}},
		&"HEAD": {"item_id": &"item_outfit_hood_ranger", "data": {}},
		&"ACCESSORY": {"item_id": &"item_outfit_scarf", "data": {"dye": "dye_sky"}}}
	var hidden := [&"HAIR"]
	r.set_outfit(CharacterRig.worn_from_slots(slots, r.body), hidden)
	await get_tree().process_frame
	assert_array(_names(r, &"TOP")).contains(["Female_Ranger_Body", "Female_Ranger_Arms"])
	assert_array(_names(r, &"TOP")).not_contains(["Female_Peasant_Body"])
	assert_array(_names(r, &"HEAD")).contains_exactly(["Female_Ranger_Head_Hood"])
	assert_bool(r.hair.visible).is_false()
	for n in r.slot_nodes[&"TOP"]:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var over := mi.get_surface_override_material(i) as BaseMaterial3D
			if src and src.resource_name.begins_with("MI_Regular"):
				assert_object(over).is_null()   # skin is never dyed
			elif over:
				assert_that(over.albedo_color).is_equal(Database.dyes[&"dye_berry"].color.lerp(Color.WHITE, 0.3))
	# the scarf has no parts: a placeholder box on the neck bone in its dye
	var acc: Array = r.slot_nodes[&"ACCESSORY"]
	assert_int(acc.size()).is_equal(1)
	assert_bool(acc[0] is BoneAttachment3D).is_true()
	assert_str((acc[0] as BoneAttachment3D).bone_name).is_equal("neck_01")
	var box := (acc[0] as Node).get_child(0) as MeshInstance3D
	assert_that(((box.mesh as BoxMesh).material as StandardMaterial3D).albedo_color).is_equal(Database.dyes[&"dye_sky"].color)
	# taking the hood off shows the hair again
	r.set_outfit({}, [])
	assert_bool(r.hair.visible).is_true()


func test_every_outfit_with_parts_builds_for_both_bodies() -> void:
	for body in [CharacterRig.MALE, CharacterRig.FEMALE]:
		var r := _rig(body)
		for id in Database.outfits:
			var def: OutfitDef = Database.outfits[id]
			if def.parts.is_empty():
				continue
			r.set_outfit(CharacterRig.worn_from_slots({def.slot: {"item_id": def.item_id, "data": {}}}, body), [])
			# each part file adds its meshes (Ranger files carry belts and bracers too)
			var names := _names(r, def.slot)
			for part in def.parts_for(body):
				assert_array(names).override_failure_message("%s %s" % [id, body]).contains([part])


func test_play_ignores_repeats_and_holds_sleep() -> void:
	var r := _rig(CharacterRig.FEMALE)
	r.play(CharacterAnimModel.for_player(PlayerTransitionTable.WALK))
	assert_str(r.current_clip).is_equal(&"Walk")
	assert_str(String(r.anim.current_animation)).is_equal("Walk")
	r.play(CharacterAnimModel.for_player(PlayerTransitionTable.SLEEP))
	assert_str(r.current_clip).is_equal(&"LayToIdle")
	assert_bool(r.anim.is_playing()).is_false()
	r.play({"clip": &"No_Such_Clip"})
	assert_str(r.current_clip).is_equal(&"LayToIdle")


func test_player_uses_the_rig_and_config_size() -> void:
	var h := Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	var p := h.player
	assert_object(p.character).is_not_null()
	assert_str(p.character.body).is_equal(p.config.body)
	var cap := p.collision_standing.shape as CapsuleShape3D
	assert_float(cap.height).is_equal_approx(1.7, 0.0001)
	assert_float(cap.radius).is_equal_approx(0.3, 0.0001)
	assert_float((p.collision_ducking.shape as CapsuleShape3D).height).is_equal_approx(0.9, 0.0001)
	assert_float(p.jump_clearance.position.y).is_equal_approx(1.9, 0.001)
	assert_float(p.camera_rig.pitch_node.position.y).is_equal_approx(1.55, 0.001)
	# running plays the run clip
	h.session.inventory.add(&"item_outfit_shirt_cotton", 1)
	p.machine.transition_to(PlayerTransitionTable.RUN, {})
	p.update_animation(null)
	assert_str(p.character.current_clip).is_equal(&"Jog_Fwd")
	h.stop()
	await get_tree().process_frame


func test_npcs_wear_their_appearance() -> void:
	for id in Database.npcs:
		var def: NpcDef = Database.npcs[id]
		assert_bool(def.appearance.get("body", &"") in [CharacterRig.MALE, CharacterRig.FEMALE]).is_true()
	var n: Npc = auto_free(Npc.new())
	n.npc_id = &"npc_tailor"
	add_child(n)
	assert_str(n.character.body).is_equal(CharacterRig.FEMALE)
	assert_array(_names(n.character, &"TOP")).contains(["Female_Ranger_Body", "Female_Ranger_Arms"])
	assert_array(_names(n.character, &"ACCESSORY")).contains_exactly(["Female_Ranger_Acc_Pauldrons"])
	assert_float(n.character.rotation.y).is_equal(0.0)
