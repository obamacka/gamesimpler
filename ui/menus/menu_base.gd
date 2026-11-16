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


## Deferred focus that tolerates the control being rebuilt or closed before it runs.
static func focus_later(c: Control) -> void:
	if c == null:
		return
	var ref: WeakRef = weakref(c)
	(func():
		var x = ref.get_ref()
		if x and x.is_inside_tree() and x.is_visible_in_tree():
			x.grab_focus()).call_deferred()


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
	b.mouse_entered.connect(func(): if b.is_inside_tree() and not b.disabled: b.grab_focus())   # hover moves focus (spec 5.9)
	return b


## A titled, scrollable list column: title, status line, rows (spec 5.1 icon-first).
var list: VBoxContainer
var status: Label
var title_label: Label


func make_list(title: String, min_size := Vector2(640, 480)) -> VBoxContainer:
	var p := MenuBase.panel(min_size)
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	title_label = Label.new()
	title_label.text = title
	v.add_child(title_label)
	status = Label.new()
	v.add_child(status)
	var sc := ScrollContainer.new()
	sc.follow_focus = true
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(min_size.x - 20, min_size.y - 100)
	v.add_child(sc)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	return list


func add_row(text: String, color: Color, on_press: Callable, enabled := true, parent: Control = null) -> Button:
	var b := MenuBase.make_button(text, color)
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if on_press.is_valid():
		b.pressed.connect(on_press)
	(parent if parent else list).add_child(b)
	return b


func clear_rows(parent: Control = null) -> void:
	for c in (parent if parent else list).get_children():
		c.queue_free()
		(parent if parent else list).remove_child(c)


func first_enabled(parent: Control = null) -> Control:
	for c in (parent if parent else list).get_children():
		if c is BaseButton and not c.disabled:
			return c
	return null


func say(text: String) -> void:
	if status:
		status.text = text
	Accessibility.speak(text)


static func item_color(item_id: StringName) -> Color:
	var it := Database.item(item_id)
	if it == null:
		return Color.GRAY
	if it.block_material != &"" and Database.materials.has(it.block_material):
		return Database.materials[it.block_material].color
	if it.piece_id != &"" and Database.pieces.has(it.piece_id):
		return Database.pieces[it.piece_id].color
	if it.outfit_id != &"" and Database.outfits.has(it.outfit_id):
		return Database.outfits[it.outfit_id].color
	return Color(0.75, 0.7, 0.6)


static func item_name(item_id: StringName) -> String:
	return String(item_id).trim_prefix("item_").replace("_", " ")


## Debug focus check (spec 5.1 rule 4): every enabled visible button must take focus.
func focus_problems() -> Array:
	var out: Array = []
	for c in find_children("*", "BaseButton", true, false):
		if c.visible and not c.disabled and c.focus_mode != Control.FOCUS_ALL:
			out.append(c.get_path())
	return out


static func panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = -min_size * 0.5
	return p
