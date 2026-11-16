# P4.15: a scripted sequence of earnings and spending lands on the exact expected total, in
# integers only.
extends GdUnitTestSuite


func test_scripted_sequence() -> void:
	var s: GameSession = auto_free(GameSession.create(9))
	add_child(s)
	s.new_game()
	var start := s.wallet.model.coins
	assert_int(start).is_equal(int(Database.economy["starting_coins"]))
	s.inventory.add(&"item_copper_ore", 7)
	var ore := Database.item(&"item_copper_ore").base_value
	var sold := s.economy.tx.try_sell(&"shop_general", &"item_copper_ore", 7)   # sell ore
	s.economy.tx.pay(120)                                                        # job pay
	s.world_state.give_drops([{"item": "coins", "qty": 33}], Vector3.ZERO)       # chest coins (Phase 2 pool)
	var bought := s.economy.tx.try_buy(&"shop_tailor", &"item_cotton_cloth", 3)  # tailor markup 110%
	var cloth := Database.item(&"item_cotton_cloth").base_value
	var expected := start + 7 * (ore * 50 / 100) + 120 + 33 - 3 * PriceModel.ceil_div(cloth * 110, 100)
	assert_bool(sold.ok and bought.ok).is_true()
	assert_int(s.wallet.model.coins).is_equal(expected)
	assert_int(typeof(s.wallet.model.coins)).is_equal(TYPE_INT)
	assert_int(typeof(sold.data)).is_equal(TYPE_INT)
	assert_int(typeof(bought.data)).is_equal(TYPE_INT)


func test_rounding_boundaries() -> void:
	assert_int(PriceModel.ceil_div(100, 100)).is_equal(1)
	assert_int(PriceModel.ceil_div(101, 100)).is_equal(2)
	assert_int(PriceModel.sell_price(2, 50, 100)).is_equal(1)
	assert_int(PriceModel.sell_price(3, 50, 100)).is_equal(1)
