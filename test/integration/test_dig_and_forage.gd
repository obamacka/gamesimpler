# P2.31: digging, drops, overflow pickups, protection, retarget, discovery, foraging, timber.
extends GdUnitTestSuite

var h: Phase2Harness


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start()
	h.session.toolbelt.model.grant(&"item_axe_basic")
	h.world.fill(Vector3i(-10, -1, -10), Vector3i(10, -1, 10), h.vid(&"mat_dirt"))
	h.place(Vector3(0.5, 0, 0.5))


func after_test() -> void:
	h.stop()
	await get_tree().process_frame


func _dig(cell: Vector3i, frames: int = 90) -> void:
	h.aim_at_cell(cell)
	await h.frames(12)
	h.press("use_pressed", {"use_held": true})
	h.hold({"use_held": true})
	await h.frames(frames)
	h.hold({})
	await h.frames(30)


func test_dig_drop_goes_to_inventory() -> void:
	await _dig(Vector3i(0, -1, 2))
	assert_int(h.world.get_voxel(Vector3i(0, -1, 2))).is_equal(0)
	assert_int(h.session.inventory.count(&"item_dirt")).is_greater_equal(1)


func test_full_inventory_spawns_pickup() -> void:
	for i in 24:
		h.session.inventory.model.slots[i] = {"item_id": &"item_wood", "qty": 99, "data": {}}
	await _dig(Vector3i(0, -1, 2), 40)
	var pickups := SceneRouter.current_zone.find_children("*", "Pickup", true, false)
	assert_int(pickups.size()).is_greater_equal(1)
	assert_str((pickups[0] as Pickup).item_id).is_equal(&"item_dirt")


func test_protected_voxel_refused_without_stamina() -> void:
	h.session.terrain.rules.add_volume(Vector3i(-1, -2, 1), Vector3i(1, 0, 3), &"TOWN")
	var before := h.session.stamina.model.current
	await _dig(Vector3i(0, -1, 2), 40)
	assert_int(h.world.get_voxel(Vector3i(0, -1, 2))).is_equal(h.vid(&"mat_dirt"))
	assert_int(h.session.stamina.model.current).is_equal(before)


func test_hold_to_dig_retargets_next_voxel() -> void:
	h.aim_at_cell(Vector3i(0, -1, 2))
	await h.frames(12)
	h.press("use_pressed", {"use_held": true})
	h.hold({"use_held": true})
	var n := 0
	while h.world.get_voxel(Vector3i(0, -1, 2)) != 0 and n < 120:
		await h.frames(1)
		n += 1
	h.aim_at_cell(Vector3i(1, -1, 2))
	await h.frames(90)
	h.hold({})
	assert_int(h.world.get_voxel(Vector3i(1, -1, 2))).is_equal(0)


func test_chest_block_reveal_and_open() -> void:
	h.world.set_voxel(Vector3i(0, -2, 2), h.vid(&"mat_chest_block"))
	var unlocked := [0]
	EventBus.unlock_granted.connect(func(_k, _i): unlocked[0] += 1)
	var coins_before := h.session.wallet.model.coins
	await _dig(Vector3i(0, -1, 2))
	var chests := SceneRouter.current_zone.find_children("*", "TreasureChest", true, false)
	assert_int(chests.size()).is_equal(1)
	assert_int(h.world.get_voxel(Vector3i(0, -2, 2))).is_equal(0)
	h.place(chests[0].global_position + Vector3(0, 0, 1.0))
	await h.frames(3)
	h.press("interact_pressed")
	await h.frames(100)
	var changed: bool = unlocked[0] > 0 or h.session.wallet.model.coins > coins_before or h.session.inventory.count(&"item_honey_bun") > 0
	assert_bool(changed).override_failure_message("chest granted nothing").is_true()
	assert_dict(h.session.world_state.chests).is_empty()


func test_geode_rock_drops_geode() -> void:
	h.world.set_voxel(Vector3i(0, -1, 2), h.vid(&"mat_geode_rock"))
	h.session.toolbelt.model.grant(&"item_pickaxe_copper")
	var found := [0]
	EventBus.geode_found.connect(func(_c): found[0] += 1)
	await _dig(Vector3i(0, -1, 2), 160)
	assert_int(h.session.inventory.count(&"item_geode")).is_equal(1)
	assert_int(found[0]).is_equal(1)


func _tree(name: String, pos: Vector3) -> AppleTree:
	var t := AppleTree.new()
	t.name = name
	h.add_scene_node(t, pos)
	return t


func test_apple_pick_with_x_and_with_rt() -> void:
	var t1 := _tree("tree_x", Vector3(-3, 0, 0.5))
	var t2 := _tree("tree_rt", Vector3(6, 0, 0.5))
	await h.frames(3)
	h.place(Vector3(-1.6, 0, 0.5))
	var stamina := h.session.stamina.model.current
	h.press("interact_pressed")
	await h.frames(100)
	assert_int(h.session.inventory.count(&"item_apple")).is_equal(4)
	assert_int(h.session.stamina.model.current).is_equal(stamina - 1)
	h.place(Vector3(4.6, 0, 0.5))
	h.aim_at_sky()
	await h.frames(15)
	assert_str(h.session.toolbelt.model.equipped).is_equal(ToolTypes.FRUIT_PICKER)
	h.press("use_pressed")
	await h.frames(100)
	assert_int(h.session.inventory.count(&"item_apple")).is_equal(8)
	assert_int(t1.fruit()).is_equal(0)
	assert_int(t2.fruit()).is_equal(0)


func test_apple_regrows_after_rollover() -> void:
	var t := _tree("tree_r", Vector3(-3, 0, 0.5))
	await h.frames(2)
	h.session.world_state.harvest_tree(t.key, Vector3.ZERO)
	h.session.rollover.run(GameClock.model.day + 2)
	assert_int(t.fruit()).is_equal(0)
	h.session.rollover.run(GameClock.model.day + 1)
	assert_int(t.fruit()).is_between(2, 4)


func test_timber_chop_and_respawn() -> void:
	var tt := TimberTree.new()
	tt.name = "timber_c"
	h.add_scene_node(tt, Vector3(-2.5, 0, 0.5))
	h.place(Vector3(-0.8, 0, 0.5))
	h.aim_at_sky()
	await h.frames(15)
	assert_str(h.session.toolbelt.model.equipped).is_equal(ToolTypes.AXE)
	h.press("use_pressed", {"use_held": true})
	h.hold({"use_held": true})
	var n := 0
	while not h.session.world_state.is_chopped(tt.key) and n < 240:
		await h.frames(1)
		n += 1
	h.hold({})
	assert_bool(h.session.world_state.is_chopped(tt.key)).is_true()
	assert_int(h.session.inventory.count(&"item_wood")).is_greater_equal(2)
	h.session.rollover.run(GameClock.model.day + 3)
	assert_bool(h.session.world_state.is_chopped(tt.key)).is_false()


func test_apple_tree_is_never_a_chop_target() -> void:
	var t := _tree("tree_axe", Vector3(-3, 0, 0.5))
	await h.frames(2)
	h.place(Vector3(-1.6, 0, 0.5))
	h.player.tool_selector.manual_select(ToolTypes.AXE)
	h.press("use_pressed", {"use_held": true})
	await h.frames(60)
	assert_bool(h.session.world_state.timber.has(t.key)).is_false()
	assert_str(h.player.machine.current_id).is_not_equal(&"mine")
