## Emote / instrument / tool wheel (spec 4.8). Stick direction picks a slot (8 per page);
## releasing the wheel button or A commits; neutral release or B cancels. Pages: Emotes,
## Instruments, Tools. result: {"kind": &"emote" | &"instrument" | &"tool", "id"} or null.
extends MenuBase

const PAGES: Array[StringName] = [&"emote", &"instrument", &"tool"]

var model := WheelModel.new()
var page := 0
var entries: Array = []
var buttons: Array[Button] = []
var _was_held := true


func build() -> void:
	make_list("Wheel", Vector2(460, 460))
	refresh()


func refresh() -> void:
	clear_rows()
	buttons.clear()
	entries = page_entries(PAGES[page])
	title_label.text = ["Emotes", "Instruments", "Tools"][page] + "  (LB/RB to switch)"
	for i in entries.size():
		var e: StringName = entries[i]
		var idx := i
		buttons.append(add_row("%d. %s" % [i + 1, String(e).get_slice("_", 1) if PAGES[page] != &"tool" else String(e).to_lower()],
			Color(0.7, 0.75, 0.95), func(): commit_slot(idx)))


## Unlocked entries for a page, at most 8 (stable order).
func page_entries(kind: StringName) -> Array:
	var s := GameSession.current
	var out: Array = []
	match kind:
		&"emote":
			for id in Database.emotes:
				if s.unlocks.model.is_unlocked(&"EMOTE", id):
					out.append(id)
		&"instrument":
			for id in Database.instruments:
				if s.unlocks.model.is_unlocked(&"INSTRUMENT", id):
					out.append(id)
		&"tool":
			for t in ToolTypes.ALL:
				if s.toolbelt.model.has_tool(t):
					out.append(t)
	return out.slice(0, 8)


func initial_focus() -> Control:
	return first_enabled()


func set_page(i: int) -> void:
	page = posmod(i, PAGES.size())
	refresh()


func commit_slot(i: int) -> void:
	if i < 0 or i >= entries.size():
		close(null)
		return
	close({"kind": PAGES[page], "id": entries[i]})


## Stick released at `dir`: commits the slot under it, or cancels at neutral.
func release(dir: Vector2) -> void:
	var s := model.release(dir)
	commit_slot(s if s < entries.size() else -1)


func _process(_delta: float) -> void:
	var dir := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	var h := model.hover(dir)
	if h >= 0 and h < buttons.size() and not buttons[h].has_focus():
		buttons[h].grab_focus()
	var held := Input.is_action_pressed(&"emote_wheel")
	if _was_held and not held and Input.get_connected_joypads().size() > 0:
		release(dir)
	_was_held = held


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_tab_next"):
		set_page(page + 1)
	elif event.is_action_pressed(&"ui_tab_prev"):
		set_page(page - 1)
