# P5.16: accessory slots, species meshes, swap, full inventory, dye data.
extends GdUnitTestSuite

var m := PetAccessoryModel.new()


func _pet(species: StringName) -> Dictionary:
	return PetModel.new(Database.pet_config).new_pet("p", species, 0, "B")


func test_valid_slot_and_species() -> void:
	var inv := InventoryModel.new(4)
	inv.add(&"item_petacc_bandana", 1)
	var pet := _pet(&"pet_cat")
	var r := m.equip(pet, inv, 0)
	assert_bool(r["ok"]).is_true()
	assert_str(r["slot"]).is_equal(&"NECK")
	assert_str(pet["accessories"]["NECK"]["item_id"]).is_equal("item_petacc_bandana")
	assert_str(pet["accessories"]["NECK"]["data"]["dye"]).is_equal("dye_berry")
	inv.add(&"item_petacc_sweater", 1)
	var slot := inv.slots.find(inv.slots.filter(func(s): return s != null and s["item_id"] == &"item_petacc_sweater")[0])
	assert_str(m.equip(pet, inv, slot)["reason"]).is_equal(PetAccessoryModel.NO_MESH)   # dog only
	assert_int(inv.count(&"item_petacc_sweater")).is_equal(1)
	inv.add(&"item_apple", 1)
	var apple := inv.slots.find(inv.slots.filter(func(s): return s != null and s["item_id"] == &"item_apple")[0])
	assert_str(m.equip(pet, inv, apple)["reason"]).is_equal(PetAccessoryModel.NOT_ACCESSORY)


func test_swap_returns_previous_with_dye() -> void:
	var inv := InventoryModel.new(4)
	inv.add(&"item_petacc_beanie", 1, {"dye": "dye_coal"})
	inv.add(&"item_petacc_beanie", 1)
	var pet := _pet(&"pet_dog")
	m.equip(pet, inv, 0)
	assert_str(pet["accessories"]["HEAD"]["data"]["dye"]).is_equal("dye_coal")
	m.equip(pet, inv, 1)
	var back: Array = inv.slots.filter(func(s): return s != null and s["item_id"] == &"item_petacc_beanie")
	assert_int(back.size()).is_equal(1)
	assert_dict(back[0]["data"]).is_equal({"dye": "dye_coal"})


func test_full_inventory_refuses_removal_unchanged() -> void:
	var inv := InventoryModel.new(1)
	inv.add(&"item_petacc_bandana", 1)
	var pet := _pet(&"pet_dog")
	m.equip(pet, inv, 0)
	inv.add(&"item_stone", 1)
	var before := inv.to_dict()
	assert_str(m.remove(pet, inv, &"NECK")["reason"]).is_equal(PetAccessoryModel.NO_SPACE)
	assert_dict(inv.to_dict()).is_equal(before)
	assert_object(pet["accessories"]["NECK"]).is_not_null()
