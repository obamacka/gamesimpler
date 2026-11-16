# P4.19: shop and crafting through the menu controllers; timed crafting in the world.
extends GdUnitTestSuite

var h: Phase2Harness
var bench: MenuStation


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	h.world.fill(Vector3i(-16, -1, -8), Vector3i(16, -1, 16), h.vid(&"mat_grass"))
	h.session.wallet.model.coins = 100
	bench = MenuStation.new()
	bench.name = "bench_test"
	bench.kind = &"WORKBENCH"
	h.add_scene_node(bench, Vector3(4.5, 0, 6.5))
	h.place(Vector3(4.5, 0, 4.8))
	h.aim_at_sky()
	await h.frames(4)


func after_test() -> void:
	h.stop()
	await get_tree().process_frame


func test_buy_and_sell_through_menu() -> void:
	var m: MenuBase = h.menus.push(&"shop", {"shop_id": &"shop_general"})
	var price := h.session.economy.tx.buy_quote(&"shop_general", &"item_seed_carrot", 1)
	assert_bool(m.buy(&"item_seed_carrot", 1).ok).is_true()
	assert_int(h.session.wallet.model.coins).is_equal(100 - price)
	assert_bool(m.sell(&"item_seed_carrot", 1).ok).is_true()
	assert_int(h.session.inventory.count(&"item_seed_carrot")).is_equal(0)
	h.menus.close_all()


func test_insufficient_coins_or_space_shows_reason_and_changes_nothing() -> void:
	h.session.wallet.model.coins = 0
	var m: MenuBase = h.menus.push(&"shop", {"shop_id": &"shop_general"})
	var before := h.session.inventory.model.to_dict()
	assert_str(m.buy(&"item_seed_carrot", 1).error).is_equal(&"not_enough_coins")
	assert_str(m.status.text).is_equal("Not enough coins")
	h.session.wallet.model.coins = 500
	for i in h.session.inventory.model.slots.size():
		h.session.inventory.model.slots[i] = {"item_id": &"item_stone", "qty": 99, "data": {}}
	before = h.session.inventory.model.to_dict()
	assert_str(m.buy(&"item_seed_carrot", 1).error).is_equal(&"no_space")
	assert_str(m.status.text).is_equal("Backpack is full")
	assert_dict(h.session.inventory.model.to_dict()).is_equal(before)
	assert_int(h.session.wallet.model.coins).is_equal(500)
	h.menus.close_all()


func _open_bench_and_choose(recipe: StringName) -> void:
	h.press("interact_pressed")
	var n := 0
	while not h.menus.is_open() and n < 60:
		await h.frames(1)
		n += 1
	assert_str(h.menus.top().menu_id).is_equal(&"crafting")
	h.menus.top().choose(recipe)
	await get_tree().process_frame
	await get_tree().process_frame


func test_timed_craft_completes_in_world() -> void:
	h.session.inventory.add(&"item_wood", 2)
	var crafted := [0]
	EventBus.item_crafted.connect(func(_r): crafted[0] += 1)
	await _open_bench_and_choose(&"recipe_piece_chair")
	await h.frames(10)
	assert_str(h.player.machine.current_id).is_equal(&"craft")
	assert_int(h.session.inventory.count(&"item_wood")).is_equal(2)   # nothing consumed until done
	await h.frames(130)   # 2.0 s
	assert_int(crafted[0]).is_equal(1)
	assert_int(h.session.inventory.count(&"item_piece_chair")).is_equal(1)
	assert_int(h.session.inventory.count(&"item_wood")).is_equal(0)
	assert_str(h.player.machine.current_id).is_equal(&"idle")


func test_moving_cancels_craft_and_consumes_nothing() -> void:
	h.session.inventory.add(&"item_wood", 2)
	var cancelled := [0]
	EventBus.craft_cancelled.connect(func(_r): cancelled[0] += 1)
	await _open_bench_and_choose(&"recipe_piece_chair")
	await h.frames(20)
	h.hold({"move": Vector2(1, 0)})
	await h.frames(3)
	h.hold({})
	assert_int(cancelled[0]).is_equal(1)
	assert_int(h.session.inventory.count(&"item_wood")).is_equal(2)
	assert_int(h.session.inventory.count(&"item_piece_chair")).is_equal(0)


func test_instant_recipe_crafts_in_menu() -> void:
	h.session.inventory.add(&"item_apple", 2)
	h.session.inventory.add(&"item_strawberry", 1)
	var m: MenuBase = h.menus.push(&"crafting", {"station": &"WORKBENCH"})
	assert_bool(m.choose(&"recipe_berry_tart").ok).is_true()
	assert_int(h.session.inventory.count(&"item_berry_tart")).is_equal(1)
	assert_str(m.choose(&"recipe_berry_tart").error).is_equal(CraftModel.MISSING_INPUTS)
	h.menus.close_all()
