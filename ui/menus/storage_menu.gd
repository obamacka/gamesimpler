## Storage chest (spec 7.3 STORAGE): backpack on the left, chest on the right; A moves one
## stack across. args: {"uid"}.
extends MenuBase

var uid: String
var mine: VBoxContainer
var theirs: VBoxContainer


func build() -> void:
	uid = String(args.get("uid", ""))
	var p := MenuBase.panel(Vector2(760, 500))
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	status = Label.new()
	v.add_child(status)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	mine = VBoxContainer.new()
	theirs = VBoxContainer.new()
	h.add_child(mine)
	h.add_child(theirs)
	refresh()


func refresh() -> void:
	var s := GameSession.current
	clear_rows(mine)
	clear_rows(theirs)
	var inv := s.inventory.model
	for i in inv.slots.size():
		var st = inv.slots[i]
		if st:
			var idx := i
			add_row("%s x%d >" % [MenuBase.item_name(st["item_id"]), st["qty"]], MenuBase.item_color(st["item_id"]), func(): store(idx, int(inv.slots[idx]["qty"])), true, mine)
	var c := s.storage.container(uid)
	for i in c.slots.size():
		var st = c.slots[i]
		var idx := i
		add_row("< %s" % ("empty" if st == null else "%s x%d" % [MenuBase.item_name(st["item_id"]), st["qty"]]),
			MenuBase.item_color(st["item_id"]) if st else Color(0.3, 0.3, 0.3), func(): take(idx, int(c.slots[idx]["qty"])), st != null, theirs)


func initial_focus() -> Control:
	var f := first_enabled(mine)
	return f if f else first_enabled(theirs)


func store(slot: int, qty: int) -> Result:
	var r := GameSession.current.storage.store(uid, slot, qty)
	if not r.ok:
		say("Chest is full")
	refresh()
	return r


func take(slot: int, qty: int) -> Result:
	var r := GameSession.current.storage.take(uid, slot, qty)
	if not r.ok:
		say("Backpack is full")
	refresh()
	return r
