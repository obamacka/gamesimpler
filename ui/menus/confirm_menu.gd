## Yes/No confirm (spec 5.8, 12.4): a picture of the question (args.icon, a Kenney icon name),
## the question in words, and two big tiles: check (yes, green) and cross (no, red).
## args: {"text", "icon", "default_yes": false}. result: &"yes" or &"no".
## The safe default (No) has focus unless default_yes is set.
extends MenuBase

var yes: Button
var no: Button


const TEXTS := {
	&"go_home_confirm": "Go home to your bed? Nothing is lost.",
	&"mine_entrance_confirm": "Enter the Deep Mine? It resets every morning.",
}
const ICONS := {&"go_home_confirm": "home", &"mine_entrance_confirm": "arrowDown"}


func build() -> void:
	if not args.has("text") and TEXTS.has(menu_id):
		args["text"] = TEXTS[menu_id]
		args["default_yes"] = true
	if not args.has("icon") and ICONS.has(menu_id):
		args["icon"] = ICONS[menu_id]
	var p := MenuBase.panel(Vector2(560, 440))
	add_child(p)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	if args.has("icon"):
		var pic := TextureRect.new()
		pic.texture = UiIcons.tile(KidTheme.CHOOSE, String(args["icon"]), 120)
		pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pic.custom_minimum_size = Vector2(120, 120)
		v.add_child(pic)
	var l := Label.new()
	l.text = args.get("text", "Are you sure?")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(480, 0)
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 48)
	v.add_child(h)
	yes = MenuBase.make_tile("Yes", "checkmark", KidTheme.GO, Vector2(170, 170))
	no = MenuBase.make_tile("No", "cross", KidTheme.STOP, Vector2(170, 170))
	h.add_child(yes)
	h.add_child(no)
	yes.focus_neighbor_right = yes.get_path_to(no)
	no.focus_neighbor_left = no.get_path_to(yes)
	yes.pressed.connect(func(): close(&"yes"))
	no.pressed.connect(func(): close(&"no"))
	result = &"no"


func initial_focus() -> Control:
	return yes if args.get("default_yes", false) else no


func on_cancel() -> void:
	close(&"no")
