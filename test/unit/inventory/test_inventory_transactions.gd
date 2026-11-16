# P4.16: move, split, merge, container transfer, full container refusals.
extends GdUnitTestSuite


func _inv(n: int = 4) -> InventoryModel:
	return InventoryModel.new(n, func(_id): return 10)


func test_move_into_empty_merge_and_swap() -> void:
	var inv := _inv()
	inv.slots[0] = {"item_id": &"item_wood", "qty": 6, "data": {}}
	inv.slots[1] = {"item_id": &"item_wood", "qty": 7, "data": {}}
	inv.slots[2] = {"item_id": &"item_stone", "qty": 1, "data": {}}
	assert_bool(inv.move_slot(0, 1)).is_true()   # merge up to 10
	assert_int(inv.slots[1]["qty"]).is_equal(10)
	assert_int(inv.slots[0]["qty"]).is_equal(3)
	assert_bool(inv.move_slot(0, 1)).is_false()   # target full
	assert_bool(inv.move_slot(0, 3)).is_true()    # into empty
	assert_object(inv.slots[0]).is_null()
	assert_bool(inv.move_slot(2, 1)).is_true()    # different items swap
	assert_str(inv.slots[1]["item_id"]).is_equal(&"item_stone")


func test_instance_data_never_merges() -> void:
	var inv := _inv()
	inv.slots[0] = {"item_id": &"item_outfit_scarf", "qty": 1, "data": {"dye": "dye_sky"}}
	inv.slots[1] = {"item_id": &"item_outfit_scarf", "qty": 1, "data": {}}
	assert_bool(inv.move_slot(0, 1)).is_true()   # swap, not merge
	assert_dict(inv.slots[1]["data"]).is_equal({"dye": "dye_sky"})


func test_split() -> void:
	var inv := _inv()
	inv.slots[0] = {"item_id": &"item_wood", "qty": 6, "data": {}}
	assert_int(inv.split(0, 2)).is_equal(1)
	assert_int(inv.slots[0]["qty"]).is_equal(4)
	assert_int(inv.slots[1]["qty"]).is_equal(2)
	assert_int(inv.split(0, 4)).is_equal(-1)   # cannot split the whole stack
	for i in range(2, 4):
		inv.slots[i] = {"item_id": &"item_stone", "qty": 1, "data": {}}
	assert_int(inv.split(0, 1)).is_equal(-1)   # no empty slot


func test_container_transfer_all_or_nothing() -> void:
	var inv := _inv()
	var chest := _inv(1)
	inv.slots[0] = {"item_id": &"item_wood", "qty": 6, "data": {}}
	assert_bool(inv.transfer_to(chest, 0, 6)).is_true()
	assert_object(inv.slots[0]).is_null()
	inv.slots[0] = {"item_id": &"item_wood", "qty": 6, "data": {}}
	assert_bool(inv.transfer_to(chest, 0, 6)).is_false()   # 10 max: only 4 fit, refused
	assert_int(inv.slots[0]["qty"]).is_equal(6)
	assert_int(chest.count(&"item_wood")).is_equal(6)
	assert_bool(inv.transfer_to(chest, 0, 4)).is_true()
	assert_int(chest.count(&"item_wood")).is_equal(10)
