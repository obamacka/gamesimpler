## Donation (spec 4.7): List (not-yet-donated collectibles in the backpack, plus "Donate all
## new") -> Confirm -> Result (case and trophy celebration), and a Geodes tab that opens geodes
## one at a time. The confirm button disables after the first press.
extends MenuBase

var tabs: TabContainer
var donate_list: VBoxContainer
var geode_list: VBoxContainer
var pending: Array = []   # ids awaiting confirm


func build() -> void:
	var p := MenuBase.panel(Vector2(720, 500))
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	status = Label.new()
	v.add_child(status)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	donate_list = _page("Donate")
	geode_list = _page("Geodes")
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


func donatable() -> Array:
	var s := GameSession.current
	var out: Array = []
	for it in Database.collectibles():
		if s.inventory.count(it.id) > 0 and not s.museum.model.is_donated(it.id):
			out.append(it.id)
	return out


func refresh() -> void:
	clear_rows(donate_list)
	clear_rows(geode_list)
	pending.clear()
	var ids := donatable()
	if ids.size() > 1:
		add_row("Donate all new (%d)" % ids.size(), Color(0.95, 0.85, 0.3), func(): ask(ids), true, donate_list)
	for id in ids:
		var i: StringName = id
		add_row(MenuBase.item_name(i), MenuBase.item_color(i), func(): ask([i]), true, donate_list, MenuBase.item_icon(i))
	if ids.is_empty():
		var l := Label.new()
		l.text = "Nothing new to donate. Keep exploring!"
		donate_list.add_child(l)
	var geodes := GameSession.current.inventory.count(&"item_geode")
	add_row("Open a geode (%d)" % geodes, Color(0.6, 0.55, 0.7), open_geode, geodes > 0, geode_list)


func initial_focus() -> Control:
	return first_enabled(donate_list) if first_enabled(donate_list) else first_enabled(geode_list)


## Confirm step: an icon grid of what will be donated, one Donate button.
func ask(ids: Array) -> void:
	pending = ids.duplicate()
	clear_rows(donate_list)
	for id in ids:
		var l := Label.new()
		l.text = "- " + MenuBase.item_name(id)
		donate_list.add_child(l)
	var btn: Button
	btn = add_row("Donate!", Color(0.5, 0.85, 0.5), func(): btn.disabled = true; confirm(), true, donate_list)
	add_row("Back", Color(0.7, 0.7, 0.7), refresh, true, donate_list)
	MenuBase.focus_later(btn)


## Result step. Returns the per-id results.
func confirm() -> Array:
	var cases := [0]
	var trophies := [0]
	var c1 := func(_c): cases[0] += 1
	var c2 := func(_t): trophies[0] += 1
	EventBus.display_case_unlocked.connect(c1)
	EventBus.trophy_unlocked.connect(c2)
	var results := GameSession.current.museum.try_donate_batch(pending)
	EventBus.display_case_unlocked.disconnect(c1)
	EventBus.trophy_unlocked.disconnect(c2)
	var ok := results.filter(func(r): return r["ok"]).size()
	var text := "Thank you! %d donated." % ok
	if cases[0] > 0:
		text += " A new display case opened!"
	if trophies[0] > 0:
		text += " You earned a trophy!"
	say(text)
	refresh()
	return results


func open_geode() -> Result:
	var r := GameSession.current.museum.open_geode()
	say(("Inside: %s!" % MenuBase.item_name(r.data)) if r.ok else ("Make room first" if r.error == &"no_space" else String(r.error)))
	refresh()
	return r
