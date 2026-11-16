# P4.14: every coordinator command is all-or-nothing; a failure injected at any mutation step
# leaves inventory, wallet, stock and deeds exactly as before.
extends GdUnitTestSuite

var s: GameSession


func before_test() -> void:
	s = GameSession.create(5)
	add_child(s)
	s.new_game()
	s.wallet.model.coins = 1000


func after_test() -> void:
	s.queue_free()


func _state() -> Dictionary:
	return {"inv": s.inventory.model.to_dict(), "coins": s.wallet.model.coins, "stock": s.economy.stock_to_dict(),
		"plots": s.housing.owned_plots.duplicate(), "belt": s.toolbelt.model.owned.duplicate()}


func _injected(cmd: Callable, steps: Array) -> void:
	for step in steps:
		var before := _state()
		s.economy.tx.fail_at = step
		var r: Result = cmd.call()
		s.economy.tx.fail_at = &""
		assert_bool(r.ok).override_failure_message("step %s should fail" % step).is_false()
		assert_dict(_state()).override_failure_message("step %s left changes" % step).is_equal(before)


func test_buy_all_or_nothing() -> void:
	_injected(func(): return s.economy.tx.try_buy(&"shop_general", &"item_seed_carrot", 3), [&"debit", &"add_items", &"stock"])
	var r := s.economy.tx.try_buy(&"shop_general", &"item_seed_carrot", 3)
	assert_bool(r.ok).is_true()
	assert_int(s.inventory.count(&"item_seed_carrot")).is_equal(3)
	assert_int(s.wallet.model.coins).is_equal(1000 - r.data)
	assert_int(s.economy.remaining(&"shop_general", &"item_seed_carrot")).is_equal(17)


func test_buy_needs_coins_space_and_stock() -> void:
	s.wallet.model.coins = 0
	assert_str(s.economy.tx.try_buy(&"shop_general", &"item_seed_carrot", 1).error).is_equal(TransactionCoordinator.NO_COINS)
	s.wallet.model.coins = 100000
	assert_str(s.economy.tx.try_buy(&"shop_general", &"item_sprinkler", 3).error).is_equal(TransactionCoordinator.OUT_OF_STOCK)
	for i in s.inventory.model.slots.size():
		s.inventory.model.slots[i] = {"item_id": &"item_stone", "qty": 99, "data": {}}
	var before := _state()
	assert_str(s.economy.tx.try_buy(&"shop_general", &"item_seed_carrot", 1).error).is_equal(TransactionCoordinator.NO_SPACE)
	assert_dict(_state()).is_equal(before)
	assert_str(s.economy.tx.try_buy(&"shop_general", &"item_wood", 1).error).is_equal(TransactionCoordinator.NOT_SOLD_HERE)


func test_buying_a_tool_grants_it() -> void:
	assert_bool(s.economy.tx.try_buy(&"shop_builder", &"item_hammer_basic", 1).ok).is_true()
	assert_bool(s.toolbelt.model.has_tool(ToolTypes.HAMMER)).is_true()
	assert_int(s.inventory.count(&"item_hammer_basic")).is_equal(0)


func test_sell_removes_exactly() -> void:
	s.inventory.add(&"item_cotton_cloth", 5)
	_injected(func(): return s.economy.tx.try_sell(&"shop_general", &"item_cotton_cloth", 2), [&"remove_items", &"credit"])
	assert_str(s.economy.tx.try_sell(&"shop_general", &"item_cotton_cloth", 6).error).is_equal(TransactionCoordinator.NOT_ENOUGH)
	var r := s.economy.tx.try_sell(&"shop_general", &"item_cotton_cloth", 2)
	assert_bool(r.ok).is_true()
	assert_int(s.inventory.count(&"item_cotton_cloth")).is_equal(3)
	assert_int(s.wallet.model.coins).is_equal(1000 + 12)   # 2 x floor(12 * 50%)


func test_craft_simulates_removal_before_output_space() -> void:
	for i in s.inventory.model.slots.size():
		s.inventory.model.slots[i] = {"item_id": &"item_stone", "qty": 99, "data": {}}
	s.inventory.model.slots[0] = {"item_id": &"item_cotton", "qty": 2, "data": {}}   # the only free slot comes from the inputs
	_injected(func(): return s.economy.tx.try_craft(&"recipe_cotton_cloth"), [&"remove_inputs", &"debit", &"add_outputs"])
	assert_bool(s.economy.tx.try_craft(&"recipe_cotton_cloth").ok).is_true()
	assert_int(s.inventory.count(&"item_cotton_cloth")).is_equal(1)
	assert_int(s.inventory.count(&"item_cotton")).is_equal(0)


func test_craft_refusals_change_nothing() -> void:
	var before := _state()
	assert_str(s.economy.tx.try_craft(&"recipe_cotton_cloth").error).is_equal(CraftModel.MISSING_INPUTS)
	assert_str(s.economy.tx.try_craft(&"recipe_piece_lamp").error).is_equal(CraftModel.LOCKED)   # blueprint
	assert_str(s.economy.tx.try_craft(&"recipe_raincoat").error).is_equal(CraftModel.LOCKED)     # tailor rank 1
	assert_dict(_state()).is_equal(before)


func test_plot_purchase_grants_deed_only_with_debit() -> void:
	_injected(func(): return s.economy.tx.try_buy_plot(&"plot_meadow_east"), [&"debit", &"deed"])
	assert_bool(s.housing.owns(&"plot_meadow_east")).is_false()
	assert_bool(s.economy.tx.try_buy_plot(&"plot_meadow_east").ok).is_true()
	assert_bool(s.housing.owns(&"plot_meadow_east")).is_true()
	assert_int(s.wallet.model.coins).is_equal(500)
	assert_str(s.economy.tx.try_buy_plot(&"plot_meadow_east").error).is_equal(TransactionCoordinator.ALREADY_OWNED)
	s.wallet.model.coins = 0
	assert_str(s.economy.tx.try_buy_plot(&"plot_test").error).is_equal(&"" if Database.plots[&"plot_test"].price_coins == 0 else TransactionCoordinator.NO_COINS)
