## Base for every menu pushed on the MenuStack (spec 5.3). Menus run WHEN_PAUSED, expose one
## initial focus control, and report a `result` to the opener's `on_close` callable.
class_name MenuBase
extends Control

var menu_id: StringName
var args: Dictionary = {}
var result: Variant = null


## Called once after the menu enters the tree; build controls here.
func build() -> void:
	pass


func initial_focus() -> Control:
	return null


## Default B / Esc behavior: close this menu.
func on_cancel() -> void:
	close()


func close(value: Variant = null) -> void:
	if value != null:
		result = value
	if MenuStack.instance and MenuStack.instance.top() == self:
		MenuStack.instance.pop()


static func make_button(text: String, color: Color = Color(0.85, 0.85, 0.85)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(140, 56)
	var icon := GradientTexture2D.new()
	icon.width = 24
	icon.height = 24
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, color)
	icon.gradient = g
	b.icon = icon
	return b


static func panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = -min_size * 0.5
	return p
