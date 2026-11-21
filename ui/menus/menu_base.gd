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


## A row button (spec 12.4): a picture on the left (an item picture, an icon tile, or a colour
## swatch) and a short caption. Hover moves focus; focus gently grows the button.
static func make_button(text: String, color: Color = Color(0.85, 0.85, 0.85), icon: Texture2D = null) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(160, 84)
	b.icon = icon if icon else UiIcons.tile(color)
	b.expand_icon = false
	b.mouse_entered.connect(func(): if b.is_inside_tree() and not b.disabled: b.grab_focus())   # hover moves focus (spec 5.9)
	add_pulse(b)
	return b


## A big picture tile (spec 12.4): coloured by meaning, white icon on top, caption below.
static func make_tile(caption: String, icon_name: String, color: Color, size := Vector2(200, 200)) -> Button:
	var b := Button.new()
	b.text = caption
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = size
	b.icon = UiIcons.icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", int(size.x * 0.55))
	KidTheme.tile_styles(b, color)
	b.mouse_entered.connect(func(): if b.is_inside_tree() and not b.disabled: b.grab_focus())
	add_pulse(b)
	return b


## Focused buttons grow 6% (none with reduce_motion) and speak their caption when TTS is on.
static func add_pulse(b: Button) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.focus_entered.connect(func():
		Accessibility.speak(b.text)
		if not Accessibility.reduce_motion() and b.is_inside_tree():
			b.create_tween().tween_property(b, "scale", Vector2(1.06, 1.06), 0.12))
	b.focus_exited.connect(func():
		if b.is_inside_tree():
			b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))


## Picture of an item for rows (spec 12.4).
static func item_icon(item_id: StringName) -> Texture2D:
	return ItemIcons.texture(item_id)


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
	title_label.add_theme_font_size_override("font_size", int(KidTheme.BASE_FONT * 1.5 * Accessibility.text_scale()))
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


func add_row(text: String, color: Color, on_press: Callable, enabled := true, parent: Control = null, icon: Texture2D = null) -> Button:
	var b := MenuBase.make_button(text, color, icon)
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if on_press.is_valid():
		b.pressed.connect(on_press)
	(parent if parent else list).add_child(b)
	return b


func add_tile(caption: String, icon_name: String, color: Color, on_press: Callable, parent: Control = null, size := Vector2(200, 200)) -> Button:
	var b := MenuBase.make_tile(caption, icon_name, color, size)
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
