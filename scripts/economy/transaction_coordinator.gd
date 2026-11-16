## All-or-nothing commands across wallet, inventory, shop stock and deeds (spec 1.5, P4.3).
## Validate everything, then mutate, then emit. `fail_at` is a test seam: the named mutation
## step fails and every earlier mutation is rolled back.
class_name TransactionCoordinator
extends RefCounted

const UNKNOWN := &"unknown"
const NOT_SOLD_HERE := &"not_sold_here"
const OUT_OF_STOCK := &"out_of_stock"
const NO_COINS := &"not_enough_coins"
const NO_SPACE := &"no_space"
const NOT_ENOUGH := &"not_enough_items"
const NOT_SELLABLE := &"not_sellable"
const ALREADY_OWNED := &"already_owned"
const INJECTED := &"injected_failure"

var session: GameSession
var fail_at: StringName = &""
var _snap: Dictionary = {}


func _init(s: GameSession) -> void:
	session = s


func _begin() -> void:
	_snap = {"inv": session.inventory.model.to_dict(), "coins": session.wallet.model.coins,
		"stock": session.economy.stock_to_dict(), "plots": session.housing.owned_plots.duplicate()}


func _rollback() -> void:
	session.inventory.model.from_dict(_snap["inv"])
	session.wallet.model.coins = _snap["coins"]
	session.economy.stock_from_dict(_snap["stock"])
	session.housing.owned_plots = _snap["plots"]


## Runs mutation steps in order; each returns true on success. On the first failure (or the
## injected one) every mutation is rolled back.
func _run(steps: Array) -> bool:
	_begin()
	for s in steps:
		if s[0] == fail_at or not (s[1] as Callable).call():
			_rollback()
			return false
	return true


func _emit_coins(old: int) -> void:
	if session.wallet.model.coins != old:
		EventBus.coins_changed.emit(old, session.wallet.model.coins)


func buy_quote(shop_id: StringName, item_id: StringName, qty: int) -> int:
	var shop: ShopDef = Database.shops.get(shop_id)
	var it := Database.item(item_id)
	return PriceModel.buy_price(it.base_value, shop.buy_pct) * qty if shop and it else -1


func sell_quote(shop_id: StringName, item_id: StringName, qty: int) -> int:
	var shop: ShopDef = Database.shops.get(shop_id)
	var it := Database.item(item_id)
	return PriceModel.sell_price(it.base_value, int(Database.economy["sell_pct"]), shop.sell_pct if shop else 100) * qty if it else -1


func try_buy(shop_id: StringName, item_id: StringName, qty: int) -> Result:
	var shop: ShopDef = Database.shops.get(shop_id)
	if shop == null or Database.item(item_id) == null or qty <= 0:
		return Result.failure(UNKNOWN)
	if not shop.sells(item_id):
		return Result.failure(NOT_SOLD_HERE)
	var left := session.economy.remaining(shop_id, item_id)
	if left >= 0 and left < qty:
		return Result.failure(OUT_OF_STOCK)
	var total := buy_quote(shop_id, item_id, qty)
	if not session.wallet.model.can_afford(total):
		return Result.failure(NO_COINS)
	var it := Database.item(item_id)
	var is_tool := it.category == &"TOOL"
	if not is_tool and not session.inventory.model.can_add(item_id, qty):
		return Result.failure(NO_SPACE)
	var old := session.wallet.model.coins
	var ok := _run([
		[&"debit", func(): return session.wallet.model.debit(total)],
		[&"add_items", func(): return true if is_tool else session.inventory.model.add(item_id, qty) == 0],
		[&"stock", func(): return session.economy.take_stock(shop_id, item_id, qty)],
	])
	if not ok:
		return Result.failure(INJECTED)
	if is_tool:
		session.toolbelt.model.grant(item_id)
	_emit_coins(old)
	if not is_tool:
		EventBus.item_added.emit(item_id, qty)
		EventBus.inventory_changed.emit()
	EventBus.item_bought.emit(shop_id, item_id, qty, total)
	return Result.success(total)


func try_sell(shop_id: StringName, item_id: StringName, qty: int) -> Result:
	var it := Database.item(item_id)
	if it == null or qty <= 0:
		return Result.failure(UNKNOWN)
	if not it.sellable or it.category == &"KEY_ITEM":
		return Result.failure(NOT_SELLABLE)
	if session.inventory.model.count(item_id) < qty:
		return Result.failure(NOT_ENOUGH)
	var total := sell_quote(shop_id, item_id, qty)
	var old := session.wallet.model.coins
	var ok := _run([
		[&"remove_items", func(): return session.inventory.model.remove(item_id, qty)],
		[&"credit", func(): return session.wallet.model.credit(total)],
	])
	if not ok:
		return Result.failure(INJECTED)
	_emit_coins(old)
	EventBus.inventory_changed.emit()
	EventBus.item_sold.emit(shop_id, item_id, qty, total)
	return Result.success(total)


func try_buy_plot(plot_id: StringName) -> Result:
	var p: PlotDef = Database.plots.get(plot_id)
	if p == null:
		return Result.failure(UNKNOWN)
	if session.housing.owns(plot_id):
		return Result.failure(ALREADY_OWNED)
	if not session.wallet.model.can_afford(p.price_coins):
		return Result.failure(NO_COINS)
	var old := session.wallet.model.coins
	var ok := _run([
		[&"debit", func(): return session.wallet.model.debit(p.price_coins)],
		[&"deed", func(): session.housing.owned_plots.append(plot_id); return true],
	])
	if not ok:
		return Result.failure(INJECTED)
	_emit_coins(old)
	EventBus.deed_granted.emit(plot_id)
	EventBus.plot_purchased.emit(plot_id, p.price_coins)
	return Result.success()


func recipe_unlocked(r: RecipeDef) -> bool:
	match r.unlock:
		&"DEFAULT":
			return true
		&"JOB_RANK":
			return session.jobs.rank(r.required_job) >= r.required_rank
		_:
			return session.unlocks.model.is_unlocked(&"BLUEPRINT", r.id)


func craft_check(recipe_id: StringName, station: StringName = &"") -> Dictionary:
	var r: RecipeDef = Database.recipes.get(recipe_id)
	if r == null:
		return {"reason": UNKNOWN, "missing": []}
	return CraftModel.check(r, session.inventory.model, session.wallet.model.coins, recipe_unlocked(r), station)


func try_craft(recipe_id: StringName, station: StringName = &"") -> Result:
	var c := craft_check(recipe_id, station)
	if c["reason"] != CraftModel.OK:
		return Result.failure(c["reason"], c["missing"])
	var r: RecipeDef = Database.recipes[recipe_id]
	var old := session.wallet.model.coins
	var ok := _run([
		[&"remove_inputs", func():
			for e in r.inputs:
				if not session.inventory.model.remove(e["item"], e["qty"]):
					return false
			return true],
		[&"debit", func(): return session.wallet.model.debit(r.coin_cost)],
		[&"add_outputs", func():
			for e in r.outputs:
				if session.inventory.model.add(e["item"], e["qty"]) > 0:
					return false
			return true],
	])
	if not ok:
		return Result.failure(INJECTED)
	_emit_coins(old)
	for e in r.outputs:
		EventBus.item_added.emit(e["item"], e["qty"])
	EventBus.inventory_changed.emit()
	EventBus.item_crafted.emit(recipe_id)
	return Result.success()


## Contract delivery: removes items then credits pay, all-or-nothing.
func try_deliver(items: Array, pay: int) -> Result:
	for e in items:
		if session.inventory.model.count(e["item"]) < int(e["qty"]):
			return Result.failure(NOT_ENOUGH)
	var old := session.wallet.model.coins
	var ok := _run([
		[&"remove_items", func():
			for e in items:
				if not session.inventory.model.remove(e["item"], e["qty"]):
					return false
			return true],
		[&"credit", func(): return session.wallet.model.credit(pay)],
	])
	if not ok:
		return Result.failure(INJECTED)
	_emit_coins(old)
	EventBus.inventory_changed.emit()
	return Result.success()


func pay(amount: int) -> void:
	var old := session.wallet.model.coins
	session.wallet.model.credit(amount)
	_emit_coins(old)
