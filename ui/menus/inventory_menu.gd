## Inventory (spec 5.8): Backpack, Outfit, Jobs, Map (placeholder); Pet and Collection
## tabs are stubs until Phases 5 and 6.
extends MenuBase

var tabs: TabContainer
var backpack: VBoxContainer
var outfit: VBoxContainer
var jobs: VBoxContainer
var selected := -1


func build() -> void:
	var p := MenuBase.panel(Vector2(760, 520))
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	status = Label.new()
	v.add_child(status)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	backpack = _page("Backpack")
	outfit = _page("Outfit")
	jobs = _page("Jobs")
	_page("Pet").add_child(_note("Your pet arrives on day 2."))
	var col := _page("Collection")
	add_row("Open the Collection Book", Color(0.9, 0.8, 0.4), func(): MenuStack.instance.push(&"collection_book"), true, col)
	var s0 := GameSession.current
	col.add_child(_note("Found %d of %d, donated %d" % [s0.collection.model.discovered.size(), Database.collectibles().size(), s0.museum.model.donated.size()]))
	_page("Map").add_child(_note("Map coming soon."))
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


func _note(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func refresh() -> void:
	var s := GameSession.current
	for c in [backpack, outfit, jobs]:
		clear_rows(c)
	var inv := s.inventory.model
	for i in inv.slots.size():
		var st = inv.slots[i]
		var idx := i
		var text := "%d. %s" % [i + 1, "empty" if st == null else "%s x%d" % [MenuBase.item_name(st["item_id"]), st["qty"]]]
		add_row(text, MenuBase.item_color(st["item_id"]) if st else Color(0.3, 0.3, 0.3), func(): activate(idx), true, backpack)
	for slot in OutfitDef.SLOTS:
		var w = s.outfit.model.slots[slot]
		var sl: StringName = slot
		add_row("%s: %s" % [slot, "none" if w == null else MenuBase.item_name(w["item_id"])], s.outfit.model.color_of(slot) if w else Color(0.3, 0.3, 0.3),
			func(): s.outfit.unequip(sl); refresh(), w != null, outfit)
	for id in s.jobs.jobs:
		add_row("%s: rank %d, %d xp" % [id.trim_prefix("job_"), s.jobs.jobs[id]["rank"], s.jobs.jobs[id]["xp"]], Color(0.6, 0.6, 0.8), Callable(), false, jobs)
	for a in s.jobs.active:
		add_row("Active: %s (due day %d)" % [a["contract_id"].trim_prefix("contract_"), a["deadline_day"]], Color(0.8, 0.7, 0.4), Callable(), false, jobs)


func initial_focus() -> Control:
	return first_enabled(backpack)


## A on a backpack slot: wear outfits; otherwise select it, and a second slot moves/swaps.
func activate(i: int) -> void:
	var s := GameSession.current
	var st = s.inventory.model.slots[i]
	if selected < 0 and st != null and Database.item(st["item_id"]).category == &"OUTFIT":
		equip_slot(i)
		return
	if selected < 0:
		selected = i if st != null else -1
		say("Pick where to move it" if selected >= 0 else "")
		return
	move(selected, i)
	selected = -1


func equip_slot(i: int) -> Result:
	var r := GameSession.current.outfit.equip_from_slot(i)
	refresh()
	return r


func move(from: int, to: int) -> bool:
	var ok := GameSession.current.inventory.model.move_slot(from, to)
	if ok:
		EventBus.inventory_changed.emit()
	refresh()
	return ok


func split(i: int, qty: int) -> int:
	var r := GameSession.current.inventory.model.split(i, qty)
	if r >= 0:
		EventBus.inventory_changed.emit()
	refresh()
	return r
