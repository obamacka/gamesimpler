# P4.16: craft checks (spec 3.2).
extends GdUnitTestSuite


func _inv() -> InventoryModel:
	return InventoryModel.new(4)


func test_reasons_in_order() -> void:
	var r: RecipeDef = Database.recipes[&"recipe_piece_lamp"]   # wood + copper ore, 5 coins
	var inv := _inv()
	assert_str(CraftModel.check(r, inv, 100, false)["reason"]).is_equal(CraftModel.LOCKED)
	var c := CraftModel.check(r, inv, 100, true)
	assert_str(c["reason"]).is_equal(CraftModel.MISSING_INPUTS)
	assert_int(c["missing"].size()).is_equal(2)
	assert_dict(c["missing"][0]).is_equal({"item": &"item_wood", "have": 0, "need": 1})
	inv.add(&"item_wood", 1)
	inv.add(&"item_copper_ore", 1)
	assert_str(CraftModel.check(r, inv, 4, true)["reason"]).is_equal(CraftModel.NO_COINS)
	assert_str(CraftModel.check(r, inv, 5, true)["reason"]).is_equal(CraftModel.OK)
	assert_str(CraftModel.check(r, inv, 5, true, &"TAILOR_BENCH")["reason"]).is_equal(CraftModel.WRONG_STATION)


func test_output_space_after_simulated_removal() -> void:
	var r: RecipeDef = Database.recipes[&"recipe_cotton_cloth"]
	var inv := InventoryModel.new(2)
	inv.add(&"item_cotton", 2)
	inv.slots[1] = {"item_id": &"item_stone", "qty": 99, "data": {}}
	assert_str(CraftModel.check(r, inv, 0, true)["reason"]).is_equal(CraftModel.OK)
	inv.add(&"item_cotton", 1)   # 3 cotton: one stays, no free slot for the cloth
	assert_str(CraftModel.check(r, inv, 0, true)["reason"]).is_equal(CraftModel.NO_SPACE)
	assert_int(inv.count(&"item_cotton")).is_equal(3)   # the check never mutates
