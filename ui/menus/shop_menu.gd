## Shop (spec 5.8): Buy and Sell lists; every action goes through the coordinator and
## failures explain themselves (no coins, no space, sold out). args: {"shop_id"}.
extends MenuBase

const REASONS := {
	&"not_enough_coins": "Not enough coins", &"no_space": "Backpack is full", &"out_of_stock": "Sold out today",
	&"not_sellable": "Cannot sell that", &"not_enough_items": "You do not have that many",
}

var shop_id: StringName
var tabs: TabContainer
var buy_list: VBoxContainer
var sell_list: VBoxContainer


func build() -> void:
	shop_id = StringName(args.get("shop_id", "shop_general"))
	var p := MenuBase.panel(Vector2(720, 500))
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	status = Label.new()
	v.add_child(status)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	buy_list = _page("Buy")
	sell_list = _page("Sell")
	refresh()


func _page(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.follow_focus = true
	tabs.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v


func refresh() -> void:
	var s := GameSession.current
	clear_rows(buy_list)
	clear_rows(sell_list)
	var shop: ShopDef = Database.shops[shop_id]
	for e in shop.stock:
		var id: StringName = e["item"]
		var left := s.economy.remaining(shop_id, id)
		var price := s.economy.tx.buy_quote(shop_id, id, 1)
		add_row("%s  %d coins  %s" % [MenuBase.item_name(id), price, "" if left < 0 else "(%d left)" % left],
			MenuBase.item_color(id), func(): buy(id, 1), left != 0, buy_list)
	var seen := {}
	for st in s.inventory.model.slots:
		if st == null or seen.has(st["item_id"]):
			continue
		var id: StringName = st["item_id"]
		seen[id] = true
		var it := Database.item(id)
		add_row("%s x%d  %d coins each" % [MenuBase.item_name(id), s.inventory.count(id), s.economy.tx.sell_quote(shop_id, id, 1)],
			MenuBase.item_color(id), func(): sell(id, 1), it.sellable, sell_list)


func initial_focus() -> Control:
	return first_enabled(buy_list)


func buy(item_id: StringName, qty: int) -> Result:
	var r := GameSession.current.economy.tx.try_buy(shop_id, item_id, qty)
	say("Bought!" if r.ok else REASONS.get(r.error, String(r.error)))
	refresh()
	return r


func sell(item_id: StringName, qty: int) -> Result:
	var r := GameSession.current.economy.tx.try_sell(shop_id, item_id, qty)
	say("Sold!" if r.ok else REASONS.get(r.error, String(r.error)))
	refresh()
	return r
