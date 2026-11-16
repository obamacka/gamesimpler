# P4.22: wardrobe and outfit customizer.
extends GdUnitTestSuite

var h: Phase2Harness


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	h.session.inventory.add(&"item_outfit_shirt_cotton", 1)
	h.session.inventory.add(&"item_outfit_hat_straw", 1)


func after_test() -> void:
	h.stop()
	await get_tree().process_frame


func _slot_of(item: StringName) -> int:
	var slots := h.session.inventory.model.slots
	for i in slots.size():
		if slots[i] and slots[i]["item_id"] == item:
			return i
	return -1


func _mesh(node: String) -> MeshInstance3D:
	return h.player.get_node("Visual/Rig/Skeleton3D/OutfitSlots/" + node)


func test_equip_changes_mesh_and_dye_applies() -> void:
	var m: MenuBase = h.menus.push(&"outfit_customizer")
	assert_bool(m.equip_slot(_slot_of(&"item_outfit_shirt_cotton")).ok).is_true()
	assert_object(_mesh("Top").mesh).is_not_null()
	assert_bool(m.set_dye(&"TOP", &"dye_berry").ok).is_true()
	var mat: StandardMaterial3D = (_mesh("Top").mesh as BoxMesh).material
	assert_that(mat.albedo_color).is_equal(Database.dyes[&"dye_berry"].color)
	assert_str(m.set_dye(&"TOP", &"dye_plum").error).is_equal(&"locked")   # dyes are unlocks (D12)
	m.confirm()
	assert_int(_slot_of(&"item_outfit_shirt_cotton")).is_equal(-1)
	assert_array(h.player.hidden_body_regions).contains([&"TORSO"])


func test_preview_animates_while_paused() -> void:
	var m: MenuBase = h.menus.push(&"outfit_customizer")
	assert_bool(get_tree().paused).is_true()
	var r0: float = m.turntable.rotation.y
	for i in 10:
		await get_tree().process_frame
	assert_float(m.turntable.rotation.y).is_not_equal(r0)
	h.menus.close_all()


func test_cancel_leaves_equipment_unchanged() -> void:
	var before := h.session.outfit.model.to_dict()
	var inv := h.session.inventory.model.to_dict()
	var m: MenuBase = h.menus.push(&"outfit_customizer")
	m.equip_slot(_slot_of(&"item_outfit_hat_straw"))
	m.set_dye(&"HEAD", &"dye_sky")
	m.cancel()
	assert_dict(h.session.outfit.model.to_dict()).is_equal(before)
	assert_dict(h.session.inventory.model.to_dict()).is_equal(inv)
	assert_object(_mesh("Head").mesh).is_null()
