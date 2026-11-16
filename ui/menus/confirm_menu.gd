## Yes/No confirm (spec 5.8). args: {"text", "icon_color", "default_yes": false}.
## result: &"yes" or &"no". The safe default (No) has focus unless default_yes is set.
extends MenuBase

var yes: Button
var no: Button


const TEXTS := {
	&"go_home_confirm": "Go home to your bed? Nothing is lost.",
	&"mine_entrance_confirm": "Enter the Deep Mine? It resets every morning.",
}


func build() -> void:
	if not args.has("text") and TEXTS.has(menu_id):
		args["text"] = TEXTS[menu_id]
		args["default_yes"] = true
	var p := MenuBase.panel(Vector2(420, 200))
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var l := Label.new()
	l.text = args.get("text", "Are you sure?")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(l)
	var h := HBoxContainer.new()
	v.add_child(h)
	yes = MenuBase.make_button("Yes", args.get("icon_color", Color(0.4, 0.8, 0.4)))
	no = MenuBase.make_button("No", Color(0.8, 0.5, 0.4))
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
