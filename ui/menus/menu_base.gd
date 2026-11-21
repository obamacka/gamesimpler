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
		Accessibility.speak(b.text if b.text != "" else b.tooltip_text)
		if not Accessibility.reduce_motion() and b.is_inside_tree():
			b.create_tween().tween_property(b, "scale", Vector2(1.06, 1.06), 0.12))
	b.focus_exited.connect(func():
		if b.is_inside_tree():
			b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))


## Item tile (spec 12.5): the item picture fills the tile; under it a big badge, either a
## count ("x12") or a coin and a price. Empty slots (item_id &"") and unavailable tiles are
## dimmed. The item name is the tooltip and the spoken caption.
static func make_item_tile(item_id: StringName, badge: String = "", price: int = -1, size := Vector2(132, 132)) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = size
	b.tooltip_text = item_name(item_id) if item_id != &"" else ""
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var pic := TextureRect.new()
	pic.name = "Picture"
	pic.custom_minimum_size = Vector2(size.x * 0.6, size.y * 0.6)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture = item_icon(item_id) if item_id != &"" else null
	v.add_child(pic)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	if price >= 0:
		var c := TextureRect.new()
		c.texture = UiIcons.coin(28)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(c)
		badge = str(price)
	var l := Label.new()
	l.name = "Badge"
	l.text = badge
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	if item_id == &"":
		b.modulate = Color(1, 1, 1, 0.45)
	b.mouse_entered.connect(func(): if b.is_inside_tree() and not b.disabled: b.grab_focus())
	add_pulse(b)
	return b


## Sets a tile's availability: dimmed and unpressable when unavailable (sold out, too dear).
static func set_tile_enabled(b: Button, on: bool) -> void:
	b.disabled = not on
	b.modulate = Color.WHITE if on else Color(1, 1, 1, 0.45)


## A scrolling grid page inside a TabContainer (spec 12.5).
static func grid_page(tabs: TabContainer, title: String, columns: int, icon: Texture2D = null) -> GridContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.follow_focus = true
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var g := GridContainer.new()
	g.columns = columns
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(g)
	if icon:
		tabs.set_tab_icon(tabs.get_tab_count() - 1, icon)
	return g


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


## Short caption for an item: "item_piece_wall_door" -> "Wall door" (spec 12.4: captions are
## extras under pictures, so short and plain).
## Pieces whose picture changed with the Quaternius art (spec 12.8): the caption follows the picture.
const RENAMED := {&"item_piece_sofa": "Bench", &"item_piece_armchair": "Stool", &"item_piece_lamp": "Candle stand",
	&"item_piece_counter": "Workbench", &"item_piece_stove": "Cauldron", &"item_piece_fridge": "Bookcase"}


static func item_name(item_id: StringName) -> String:
	if RENAMED.has(item_id):
		return RENAMED[item_id]
	var s := String(item_id).trim_prefix("item_")
	for p in ["piece_", "outfit_", "petacc_", "seed_"]:
		if s.begins_with(p):
			s = s.trim_prefix(p) + (" seeds" if p == "seed_" else "")
	return s.replace("_", " ").capitalize() if s.length() > 0 else s


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
