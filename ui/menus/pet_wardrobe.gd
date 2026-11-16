## Pet wardrobe (spec 5.8, 7.1): slots HEAD, NECK, BODY; accessories from the backpack;
## accessories without a mesh for this species are greyed out; dye by name.
extends MenuBase

var slots_col: VBoxContainer
var items_col: VBoxContainer
var dyes_col: VBoxContainer
var current: StringName = &"HEAD"


func build() -> void:
	var p := MenuBase.panel(Vector2(820, 480))
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	status = Label.new()
	v.add_child(status)
	var h := HBoxContainer.new()
	v.add_child(h)
	slots_col = VBoxContainer.new()
	items_col = VBoxContainer.new()
	dyes_col = VBoxContainer.new()
	for c in [slots_col, items_col, dyes_col]:
		h.add_child(c)
	refresh()


func refresh() -> void:
	var s := GameSession.current
	for c in [slots_col, items_col, dyes_col]:
		clear_rows(c)
	if not s.pets.has_pet():
		say("No pet yet.")
		return
	var pet: Dictionary = s.pets.pet()
	for slot in PetAccessoryDef.SLOTS:
		var sl: StringName = slot
		var st = pet["accessories"][String(slot)]
		add_row("%s: %s" % [slot, "none" if st == null else MenuBase.item_name(st["item_id"])], PetAccessoryModel.color_of(st) if st else Color(0.3, 0.3, 0.3),
			func(): current = sl; refresh(), true, slots_col)
	var inv := s.inventory.model
	for i in inv.slots.size():
		var st = inv.slots[i]
		if st == null or Database.item(st["item_id"]).category != &"PET_ACCESSORY":
			continue
		var a: PetAccessoryDef = Database.pet_accessories[st["item_id"]]
		if a.slot != current:
			continue
		var idx := i
		var fits := PetAccessoryModel.can_equip(st["item_id"], StringName(pet["species_id"])) == &""
		add_row(("Wear " if fits else "Does not fit: ") + MenuBase.item_name(st["item_id"]), a.color, func(): equip(idx), fits, items_col)
	if pet["accessories"][String(current)] != null:
		add_row("Take off", Color(0.8, 0.5, 0.4), func(): remove(current), true, items_col)
		for id in Database.dyes:
			if s.unlocks.model.is_unlocked(&"DYE", id):
				var did: StringName = id
				add_row(Database.dyes[id].name_key, Database.dyes[id].color, func(): s.pets.set_accessory_dye(current, did); refresh(), true, dyes_col)


func initial_focus() -> Control:
	return first_enabled(slots_col)


func equip(i: int) -> Result:
	var r := GameSession.current.pets.equip_accessory(i)
	if r.ok:
		current = r.data
	else:
		say("Does not fit" if r.error == PetAccessoryModel.NO_MESH else String(r.error))
	refresh()
	return r


func remove(slot: StringName) -> Result:
	var r := GameSession.current.pets.remove_accessory(slot)
	if not r.ok:
		say("Make room in your backpack first" if r.error == PetAccessoryModel.NO_SPACE else String(r.error))
	refresh()
	return r
