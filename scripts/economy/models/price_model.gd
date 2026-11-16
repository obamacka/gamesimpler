## Integer pricing (spec 1.8): buy rounds up, sell rounds down, default sell 50% of
## base_value. All math in ints (no floats in currency paths).
class_name PriceModel
extends RefCounted


static func buy_price(base_value: int, shop_buy_pct: int) -> int:
	return maxi(1, ceil_div(base_value * shop_buy_pct, 100))


static func sell_price(base_value: int, economy_sell_pct: int, shop_sell_pct: int) -> int:
	return (base_value * economy_sell_pct * shop_sell_pct) / 10000


static func ceil_div(a: int, b: int) -> int:
	return (a + b - 1) / b
