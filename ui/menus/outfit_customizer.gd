## Wardrobe (spec 5.8, P4.8): equip outfit pieces from the backpack, dye them by name and
## swatch, preview on a turntable that spins while paused. Cancel restores what you wore.
extends MenuBase

var preview: SubViewportContainer
var turntable: Node3D
var mannequin: CharacterRig
var slots_col: VBoxContainer
var items_col: VBoxContainer
var dyes_col: VBoxContainer
var current_slot: StringName = &"HEAD"
var _snap: Dictionary


func build() -> void:
	var s := GameSession.current
	_snap = s.outfit.snapshot()
	var p := MenuBase.panel(Vector2(900, 520))
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	status = Label.new()
	v.add_child(status)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	preview = SubViewportContainer.new()
	preview.custom_minimum_size = Vector2(260, 360)
	preview.stretch = true
	h.add_child(preview)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	preview.add_child(vp)
	turntable = Node3D.new()
	vp.add_child(turntable)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 2.8)
	vp.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.7, 0.4, 0)
	vp.add_child(light)
	slots_col = VBoxContainer.new()
	items_col = VBoxContainer.new()
	dyes_col = VBoxContainer.new()
	for c in [slots_col, items_col, dyes_col]:
		h.add_child(c)
	var bottom := HBoxContainer.new()
	v.add_child(bottom)
	add_row("Done", Color(0.5, 0.8, 0.5), confirm, true, bottom)
	add_row("Cancel", Color(0.8, 0.5, 0.4), cancel, true, bottom)
	refresh()


func _process(delta: float) -> void:
	if turntable and not Accessibility.reduce_motion():
		turntable.rotate_y(delta * 0.8)


func refresh() -> void:
	var s := GameSession.current
	for c in [slots_col, items_col, dyes_col]:
		clear_rows(c)
	for slot in OutfitDef.SLOTS:
		var sl: StringName = slot
		var w = s.outfit.model.slots[slot]
		add_row("%s: %s" % [slot, "none" if w == null else MenuBase.item_name(w["item_id"])], s.outfit.model.color_of(slot) if w else Color(0.3, 0.3, 0.3),
			func(): current_slot = sl; refresh(), true, slots_col)
	var inv := s.inventory.model
	for i in inv.slots.size():
		var st = inv.slots[i]
		if st == null or Database.item(st["item_id"]).category != &"OUTFIT":
			continue
		if OutfitModel.outfit_of(st["item_id"]).slot != current_slot:
			continue
		var idx := i
		add_row("Wear %s" % MenuBase.item_name(st["item_id"]), MenuBase.item_color(st["item_id"]), func(): equip_slot(idx), true, items_col, MenuBase.item_icon(st["item_id"]))
	if s.outfit.model.slots[current_slot] != null:
		for id in Database.dyes:
			if s.unlocks.model.is_unlocked(&"DYE", id):
				var dye: DyeDef = Database.dyes[id]
				var did: StringName = id
				add_row(dye.name_key, dye.color, func(): set_dye(current_slot, did), true, dyes_col)
	_rebuild_mannequin()


## Preview (spec 11.5): the player's character rig, idling while the tree is paused.
func _rebuild_mannequin() -> void:
	var s := GameSession.current
	if mannequin == null:
		var p := SceneRouter.player
		var cfg: PlayerConfig = p.config if p is PlayerController else PlayerConfig.new()
		mannequin = CharacterRig.new()
		mannequin.process_mode = Node.PROCESS_MODE_ALWAYS
		turntable.add_child(mannequin)
		mannequin.setup(cfg.body, cfg.hair)
		mannequin.rotation.y = 0.0   # face the preview camera (+Z)
	mannequin.set_outfit(CharacterRig.worn_from_slots(s.outfit.model.slots, mannequin.body), s.outfit.model.hidden_regions())


func initial_focus() -> Control:
	return first_enabled(slots_col)


func equip_slot(i: int) -> Result:
	var r := GameSession.current.outfit.equip_from_slot(i)
	if r.ok:
		current_slot = r.data
	refresh()
	return r


func set_dye(slot: StringName, dye_id: StringName) -> Result:
	var r := GameSession.current.outfit.set_dye(slot, dye_id)
	if r.ok:
		say(Database.dyes[dye_id].name_key)
	refresh()
	return r


func confirm() -> void:
	close(&"done")


func cancel() -> void:
	GameSession.current.outfit.restore(_snap)
	close(&"cancelled")


func on_cancel() -> void:
	cancel()
