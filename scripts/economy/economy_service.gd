## Shops, pricing and daily restock (spec 1.8, P4.4). Holds the TransactionCoordinator.
class_name EconomyService
extends Node

var session: GameSession
var tx: TransactionCoordinator
var stock: Dictionary = {}   # shop_id -> {"stock_day": int, "remaining": {item_id: int}}


func setup(s: GameSession) -> void:
	session = s
	tx = TransactionCoordinator.new(s)
	restock(1)


## Rollover step `restock` (spec 6.2).
func restock(day: int) -> void:
	stock.clear()
	for id in Database.shops:
		var rem := {}
		for e in Database.shops[id].stock:
			if int(e["daily"]) >= 0:
				rem[String(e["item"])] = int(e["daily"])
		stock[String(id)] = {"stock_day": day, "remaining": rem}


## -1 = unlimited, 0 = sold out or not stocked.
func remaining(shop_id: StringName, item_id: StringName) -> int:
	var shop: ShopDef = Database.shops.get(shop_id)
	if shop == null or not shop.sells(item_id):
		return 0
	if shop.daily_of(item_id) < 0:
		return -1
	return int(stock.get(String(shop_id), {}).get("remaining", {}).get(String(item_id), 0))


func take_stock(shop_id: StringName, item_id: StringName, qty: int) -> bool:
	var left := remaining(shop_id, item_id)
	if left < 0:
		return true
	if left < qty:
		return false
	stock[String(shop_id)]["remaining"][String(item_id)] = left - qty
	return true


func stock_to_dict() -> Dictionary:
	return stock.duplicate(true)


func stock_from_dict(d: Dictionary) -> void:
	stock = {}
	for id in d:
		var rem := {}
		for k in d[id].get("remaining", {}):
			rem[String(k)] = int(d[id]["remaining"][k])
		stock[String(id)] = {"stock_day": int(d[id].get("stock_day", 1)), "remaining": rem}
