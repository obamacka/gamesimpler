# P2.27: stacking, instance data, overflow, all-or-nothing removal, plain stacks first.
extends GdUnitTestSuite


func _inv(slots: int = 3, stack: int = 10) -> InventoryModel:
	return InventoryModel.new(slots, func(_id): return stack)


func test_stacks_merge_and_overflow() -> void:
	var inv := _inv(2, 10)
	assert_int(inv.add(&"a", 15)).is_equal(0)
	assert_int(inv.add(&"a", 8)).is_equal(3)
	assert_int(inv.count(&"a")).is_equal(20)


func test_instance_data_never_merges() -> void:
	var inv := _inv(3, 1)
	inv.add(&"shirt", 1, {"dye": "dye_moss"})
	inv.add(&"shirt", 1, {"dye": "dye_moss"})
	assert_int(inv.slots.filter(func(s): return s != null).size()).is_equal(2)


func test_can_add_and_space() -> void:
	var inv := _inv(1, 10)
	inv.add(&"a", 7)
	assert_bool(inv.can_add(&"a", 3)).is_true()
	assert_bool(inv.can_add(&"a", 4)).is_false()
	assert_bool(inv.can_add(&"b", 1)).is_false()


func test_remove_all_or_nothing_plain_first() -> void:
	var inv := _inv(3, 10)
	inv.add(&"cloth", 1, {"dye": "dye_sky"})
	inv.add(&"cloth", 1)
	assert_bool(inv.remove(&"cloth", 3)).is_false()
	assert_int(inv.count(&"cloth")).is_equal(2)
	assert_bool(inv.remove(&"cloth", 1)).is_true()
	var left: Dictionary = inv.slots.filter(func(s): return s != null)[0]
	assert_dict(left["data"]).is_equal({"dye": "dye_sky"})


func test_round_trip() -> void:
	var inv := _inv(3, 10)
	inv.add(&"a", 6)
	inv.add(&"b", 1, {"dye": "x"})
	var inv2 := _inv(3, 10)
	inv2.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	assert_dict(inv2.to_dict()).is_equal(inv.to_dict())
	assert_int(typeof(inv2.slots[0]["qty"])).is_equal(TYPE_INT)
