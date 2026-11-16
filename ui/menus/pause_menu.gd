## Pause menu (spec 5.8): Resume, Go Home (D19), Save and Load (Phase 6), Settings, Quit.
extends MenuBase

var resume_btn: Button


func build() -> void:
	make_list("Paused", Vector2(420, 460))
	resume_btn = add_row("Resume", Color(0.5, 0.8, 0.5), func(): close())
	add_row("Go Home", Color(0.9, 0.7, 0.4), go_home)
	add_row("Save", Color(0.6, 0.8, 0.6), func(): MenuStack.instance.push(&"save_load", {"mode": &"save"}))
	add_row("Load", Color(0.6, 0.7, 0.8), func(): MenuStack.instance.push(&"save_load", {"mode": &"load"}))
	add_row("Settings", Color(0.6, 0.7, 0.9), func(): MenuStack.instance.push(&"settings"))
	add_row("Quit", Color(0.8, 0.4, 0.4), func(): get_tree().quit())


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
