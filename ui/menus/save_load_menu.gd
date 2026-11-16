## Save / Load (spec 5.8, 3.5): three manual slots plus the autosave (load only).
## args: {"mode": &"save" | &"load"}.
extends MenuBase

var mode: StringName = &"save"


func build() -> void:
	mode = StringName(args.get("mode", "save"))
	make_list("Save game" if mode == &"save" else "Load game", Vector2(520, 380))
	refresh()


func refresh() -> void:
	clear_rows()
	var slots: Array = SaveService.SLOTS.duplicate()
	if mode == &"load":
		slots.push_front(SaveService.AUTOSAVE_SLOT)
	for slot in slots:
		var info := SaveService.slot_info(slot)
		var label := ("Autosave" if slot == 0 else "Slot %d" % slot) + (": day %d, %d coins" % [info["day"], info["coins"]] if info["exists"] else ": empty")
		var sl: int = slot
		add_row(label, Color(0.6, 0.75, 0.9), func(): choose(sl), mode == &"save" or info["exists"])


func initial_focus() -> Control:
	return first_enabled()


func choose(slot: int) -> Result:
	var s := GameSession.current
	var r: Result
	if mode == &"save":
		r = await SaveService.save_slot(slot, s)
		say("Saved!" if r.ok else "Could not save right now")
		refresh()
		return r
	MenuStack.instance.close_all()
	r = await SaveService.load_into(slot, s)
	return r
