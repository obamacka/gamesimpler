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


## Nodes the character rig shows for a slot (spec 11.5, 11.6).
func _slot(slot: StringName) -> Array:
	return h.player.character.slot_nodes.get(slot, []).filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion())


## Albedo of the first cloth surface (not skin) of a slot's meshes.
func _cloth_color(slot: StringName) -> Color:
	for n in _slot(slot):
		if n is MeshInstance3D:
			for i in (n as MeshInstance3D).mesh.get_surface_count():
				var m := (n as MeshInstance3D).get_surface_override_material(i) as BaseMaterial3D
				if m:
					return m.albedo_color
	return Color.TRANSPARENT


func test_equip_changes_mesh_and_dye_applies() -> void:
	var m: MenuBase = h.menus.push(&"outfit_customizer")
	assert_bool(m.equip_slot(_slot_of(&"item_outfit_shirt_cotton")).ok).is_true()
	var names := _slot(&"TOP").map(func(n): return String(n.name))
	assert_array(names).contains(["Female_Peasant_Body", "Female_Peasant_Arms"])
	assert_bool(m.set_dye(&"TOP", &"dye_berry").ok).is_true()
	assert_that(_cloth_color(&"TOP")).is_equal(Database.dyes[&"dye_berry"].color.lerp(Color.WHITE, 0.3))
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
	assert_array(_slot(&"HEAD")).is_empty()   # no hat placeholder: cancelled
