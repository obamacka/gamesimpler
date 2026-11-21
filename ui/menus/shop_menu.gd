## Shop (spec 5.8, 12.5): Buy and Sell grids of item picture tiles with coin prices; the tabs
## are pictures (basket = buy, coin = sell). Every action goes through the coordinator and
## failures explain themselves (no coins, no space, sold out). args: {"shop_id"}.
extends MenuBase

const REASONS := {
	&"not_enough_coins": "Not enough coins", &"no_space": "Backpack is full", &"out_of_stock": "Sold out today",
	&"not_sellable": "Cannot sell that", &"not_enough_items": "You do not have that many",
}

var shop_id: StringName
var tabs: TabContainer
var buy_list: GridContainer
var sell_list: GridContainer


func build() -> void:
	shop_id = StringName(args.get("shop_id", "shop_general"))
	var p := MenuBase.panel(Vector2(760, 600))
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	status = Label.new()
	v.add_child(status)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	buy_list = MenuBase.grid_page(tabs, "Buy", 4, UiIcons.tile(KidTheme.CHOOSE, "shoppingBasket", 44))
	sell_list = MenuBase.grid_page(tabs, "Sell", 4, UiIcons.coin(44))
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
		var t := MenuBase.make_item_tile(id, "", price, Vector2(150, 150))
		t.tooltip_text = MenuBase.item_name(id) + ("" if left < 0 else " (%d left)" % left)
		MenuBase.set_tile_enabled(t, left != 0)
		t.pressed.connect(func(): buy(id, 1))
		buy_list.add_child(t)
	var seen := {}
	for st in s.inventory.model.slots:
		if st == null or seen.has(st["item_id"]):
			continue
		var id: StringName = st["item_id"]
		seen[id] = true
		var it := Database.item(id)
		var t := MenuBase.make_item_tile(id, "", s.economy.tx.sell_quote(shop_id, id, 1), Vector2(150, 150))
		var count := Label.new()
		count.text = "x%d" % s.inventory.count(id)
		count.position = Vector2(8, 4)
		t.add_child(count)
		MenuBase.set_tile_enabled(t, it.sellable)
		t.pressed.connect(func(): sell(id, 1))
		sell_list.add_child(t)


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
