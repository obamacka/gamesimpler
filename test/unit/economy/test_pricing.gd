# P4.16: buy rounds up, sell rounds down, default sell 50% (spec 1.8).
extends GdUnitTestSuite


func test_buy_rounds_up() -> void:
	assert_int(PriceModel.buy_price(10, 100)).is_equal(10)
	assert_int(PriceModel.buy_price(10, 110)).is_equal(11)
	assert_int(PriceModel.buy_price(7, 110)).is_equal(8)    # 7.7 -> 8
	assert_int(PriceModel.buy_price(9, 101)).is_equal(10)   # 9.09 -> 10
	assert_int(PriceModel.buy_price(0, 100)).is_equal(1)    # nothing is free in a shop


func test_sell_rounds_down() -> void:
	assert_int(PriceModel.sell_price(10, 50, 100)).is_equal(5)
	assert_int(PriceModel.sell_price(7, 50, 100)).is_equal(3)    # 3.5 -> 3
	assert_int(PriceModel.sell_price(1, 50, 100)).is_equal(0)
	assert_int(PriceModel.sell_price(13, 50, 110)).is_equal(7)   # 7.15 -> 7


func test_quotes_use_shop_multipliers() -> void:
	var s: GameSession = auto_free(GameSession.create(1))
	add_child(s)
	var it := Database.item(&"item_cotton_cloth")
	assert_int(s.economy.tx.buy_quote(&"shop_tailor", &"item_cotton_cloth", 2)).is_equal(2 * PriceModel.buy_price(it.base_value, 110))
	assert_int(s.economy.tx.sell_quote(&"shop_general", &"item_cotton_cloth", 3)).is_equal(3 * (it.base_value * 50 / 100))
