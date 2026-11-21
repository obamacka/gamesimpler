## Title screen (spec 12.1): big picture tiles, gamepad focus left to right, A chooses.
## Play continues the newest save or starts a new game; New (only with a save) confirms first;
## Settings opens the settings menu; Quit (desktop) confirms first.
class_name TitleScreen
extends CanvasLayer

signal play_pressed
signal new_pressed

var root: Control
var tiles: HBoxContainer
var play_btn: Button
var new_btn: Button
var settings_btn: Button
var quit_btn: Button


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var name_label := Label.new()
	name_label.text = String(ProjectSettings.get_setting("application/config/name", "Gamesimpler"))
	name_label.add_theme_font_size_override("font_size", 96)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", KidTheme.INK)
	name_label.add_theme_constant_override("outline_size", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	name_label.offset_left = -600
	name_label.offset_right = 600
	name_label.offset_top = 60
	root.add_child(name_label)
	tiles = HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", 40)
	tiles.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tiles.offset_left = -700
	tiles.offset_right = 700
	tiles.offset_top = -330
	tiles.offset_bottom = -70
	root.add_child(tiles)
	refresh()


## Rebuilds the tiles (a save may have appeared or gone).
func refresh() -> void:
	for c in tiles.get_children():
		tiles.remove_child(c)
		c.queue_free()
	var has_save := SaveService.latest_slot() >= 0
	play_btn = _tile("Play", "right", KidTheme.GO, func(): play_pressed.emit(), Vector2(260, 260))
	new_btn = null
	if has_save:
		new_btn = _tile("New", "plus", KidTheme.CHOOSE, _confirm_new)
	settings_btn = _tile("Settings", "gear", KidTheme.EXTRA, func(): MenuStack.instance.push(&"settings"))
	quit_btn = null
	if OS.has_feature("pc"):
		quit_btn = _tile("Quit", "power", KidTheme.STOP, _confirm_quit)
	MenuBase.focus_later(play_btn)


func _tile(caption: String, icon: String, color: Color, on_press: Callable, size := Vector2(220, 220)) -> Button:
	var b := MenuBase.make_tile(caption, icon, color, size)
	b.pressed.connect(on_press)
	tiles.add_child(b)
	return b


func _confirm_new() -> void:
	MenuStack.instance.push(&"confirm", {"text": "Start a new game?", "icon": "plus", "default_yes": false,
		"on_close": func(r): if r == &"yes": new_pressed.emit()})


func _confirm_quit() -> void:
	MenuStack.instance.push(&"confirm", {"text": "Stop playing?", "icon": "power", "default_yes": false,
		"on_close": func(r): if r == &"yes": get_tree().quit()})


func initial_focus() -> Control:
	return play_btn
