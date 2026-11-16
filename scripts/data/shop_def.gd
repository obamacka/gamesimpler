## Shop (spec 3.4). stock: [{"item": StringName, "daily": int}] (-1 = unlimited).
class_name ShopDef
extends Resource

@export var id: StringName
@export var buy_pct := 100
@export var sell_pct := 100
@export var stock: Array = []


func daily_of(item_id: StringName) -> int:
	for s in stock:
		if s["item"] == item_id:
			return s["daily"]
	return 0


func sells(item_id: StringName) -> bool:
	return stock.any(func(s): return s["item"] == item_id)
