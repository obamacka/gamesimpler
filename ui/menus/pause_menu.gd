## Pause menu (spec 5.8, 12.4): a 3 x 2 grid of picture tiles. Resume, Go Home (D19), Save,
## Load, Settings, and Title (autosaves, then the title screen; Quit lives on the title).
extends MenuBase

var resume_btn: Button
var grid: GridContainer


func build() -> void:
	var p := MenuBase.panel(Vector2(760, 560))
	add_child(p)
	grid = GridContainer.new()
	grid.columns = 3
	p.add_child(grid)
	var t := Vector2(210, 210)
	resume_btn = add_tile("Play", "right", KidTheme.GO, func(): close(), grid, t)
	add_tile("Home", "home", KidTheme.MONEY, go_home, grid, t)
	add_tile("Save", "save", KidTheme.CHOOSE, func(): MenuStack.instance.push(&"save_load", {"mode": &"save"}), grid, t)
	add_tile("Load", "open", KidTheme.CHOOSE, func(): MenuStack.instance.push(&"save_load", {"mode": &"load"}), grid, t)
	add_tile("Settings", "gear", KidTheme.EXTRA, func(): MenuStack.instance.push(&"settings"), grid, t)
	add_tile("Title", "exitLeft", KidTheme.STOP, to_title, grid, t)


func initial_focus() -> Control:
	return resume_btn


func go_home() -> void:
	if bool(Settings.get_value("assist", "go_home_confirm")):
		MenuStack.instance.push(&"go_home_confirm", {"on_close": func(r): if r == &"yes": _do_go_home()})
	else:
		_do_go_home()


func _do_go_home() -> void:
	var stack := MenuStack.instance
	stack.close_all()
	var s := GameSession.current
	if s:
		stack.after_resume(func(): s.sleep.go_home())


func to_title() -> void:
	MenuStack.instance.push(&"confirm", {"text": "Back to the start screen? Your game is saved.", "icon": "exitLeft", "default_yes": true,
		"on_close": func(r):
			if r == &"yes":
				var m := get_tree().get_first_node_in_group(&"main")
				if m and m.has_method("return_to_title"):
					m.return_to_title()})
