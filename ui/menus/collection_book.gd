## Collection Book (spec 5.8): pages per category; undiscovered entries are silhouettes with
## a hint on focus, discovered ones show their icon, donated ones also a ribbon.
extends MenuBase

const PAGES: Array[StringName] = [&"MINERAL", &"FABRIC", &"PRODUCE", &"STICKER"]

var page := 0
var hint: Label


func build() -> void:
	make_list("Collection Book", Vector2(640, 480))
	hint = Label.new()
	list.get_parent().get_parent().add_child(hint)
	refresh()


## Each row: {"id", "state": &"hidden"|&"found"|&"donated", "text"}.
func entries(category: StringName) -> Array:
	var s := GameSession.current
	var out: Array = []
	if category == &"STICKER":
		for id in Database.stickers:
			var got := s.unlocks.model.is_unlocked(&"STICKER", id)
			out.append({"id": id, "state": &"found" if got else &"hidden", "text": Database.stickers[id].name_key if got else "???", "hint": "Found in treasure chests"})
		return out
	for it in Database.collectibles():
		if it.collection.category != category:
			continue
		var st := &"hidden"
		if s.museum.model.is_donated(it.id):
			st = &"donated"
		elif s.collection.model.is_discovered(it.id):
			st = &"found"
		var name := MenuBase.item_name(it.id)
		out.append({"id": it.id, "state": st, "text": "???" if st == &"hidden" else (name + ("  [ribbon]" if st == &"donated" else "")), "hint": it.collection.hint_key})
	return out


func refresh() -> void:
	clear_rows()
	title_label.text = "Collection Book: %s  (LB/RB to turn the page)" % String(PAGES[page]).capitalize()
	for e in entries(PAGES[page]):
		var color: Color = Color(0.15, 0.15, 0.15) if e["state"] == &"hidden" else (MenuBase.item_color(e["id"]) if PAGES[page] != &"STICKER" else Database.stickers[e["id"]].color)
		var b := add_row(e["text"], color, Callable())
		var h: String = e["hint"]
		b.focus_entered.connect(func(): hint.text = h if e["state"] == &"hidden" else "")


func initial_focus() -> Control:
	return list.get_child(0) if list.get_child_count() > 0 else null


func set_page(i: int) -> void:
	page = posmod(i, PAGES.size())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_tab_next"):
		set_page(page + 1)
	elif event.is_action_pressed(&"ui_tab_prev"):
		set_page(page - 1)
