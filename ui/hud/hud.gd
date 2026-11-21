## HUD (spec 12.4): pictures first. Top left: sun or moon with the day number, a heart with the
## stamina bar, a coin with the coins, a letter with unread mail. Bottom centre: pictures of the
## equipped tool and the held hotbar item (with the watering-can level when it matters).
## Messages (toasts) show as a big banner at the top.
extends CanvasLayer

var _stamina: ProgressBar
var _day_icon: HudIcon
var _day: Label
var _coins: Label
var _mail_pill: Control
var _mail: Label
var _tool_pic: TextureRect
var _held_pic: TextureRect
var _held_qty: Label
var _can_pill: Control
var _can: ProgressBar
var _toast_panel: PanelContainer
var _toast: Label
var _toast_t := 0.0


func _ready() -> void:
	var top := VBoxContainer.new()
	top.position = Vector2(24, 20)
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	_day_icon = HudIcon.new(HudIcon.Kind.SUN)
	_day = _label()
	top.add_child(_pill([_day_icon, _day]))
	_stamina = ProgressBar.new()
	_stamina.custom_minimum_size = Vector2(240, 26)
	_stamina.show_percentage = false
	_stamina.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_pill([HudIcon.new(HudIcon.Kind.HEART), _stamina]))
	_coins = _label()
	top.add_child(_pill([HudIcon.new(HudIcon.Kind.COIN), _coins]))
	_mail = _label()
	_mail_pill = _pill([HudIcon.new(HudIcon.Kind.MAIL), _mail])
	top.add_child(_mail_pill)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.offset_left = -300
	bottom.offset_right = 300
	bottom.offset_top = -120
	bottom.offset_bottom = -24
	add_child(bottom)
	_tool_pic = _picture()
	bottom.add_child(_pill([_tool_pic]))
	_held_pic = _picture()
	_held_qty = _label()
	bottom.add_child(_pill([_held_pic, _held_qty]))
	_can = ProgressBar.new()
	_can.custom_minimum_size = Vector2(120, 20)
	_can.show_percentage = false
	_can.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_can.add_theme_stylebox_override("fill", KidTheme.box(KidTheme.CHOOSE, 10, 0, Color.TRANSPARENT, 0))
	_can_pill = _pill([HudIcon.new(HudIcon.Kind.WATER), _can])
	bottom.add_child(_can_pill)

	_toast_panel = PanelContainer.new()
	_toast_panel.add_theme_stylebox_override("panel", _pill_box())
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.offset_left = -360
	_toast_panel.offset_right = 360
	_toast_panel.offset_top = 24
	_toast = _label()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD
	_toast_panel.add_child(_toast)
	_toast_panel.visible = false
	add_child(_toast_panel)

	EventBus.stamina_low.connect(func(pct): toast("Feeling tired (%d%%)" % pct))
	EventBus.prompt_changed.connect(func(_k, state, _t): toast(PromptModel.BLOCKED_TEXT.get(state, "")))
	EventBus.mail_delivered.connect(func(_ids): toast("Mail arrived"))
	EventBus.chest_opened.connect(func(_k, r): toast("Treasure: %s" % (r["id"] if r["id"] != &"" else ("%d coins" % r["coins"] if r["coins"] > 0 else r["item"]))))
	EventBus.stuck_hint.connect(func(): toast("Stuck? Try Go Home from the pause menu"))
	EventBus.crop_harvested.connect(func(_c, crop_id, qty): toast("Harvested %d %s" % [qty, String(crop_id).trim_prefix("crop_")]))
	EventBus.can_refilled.connect(func(_w): toast("Watering can full"))


static func _pill_box() -> StyleBoxFlat:
	var b := KidTheme.box(Color(0.12, 0.1, 0.16, 0.55), 22, 0, Color.TRANSPARENT, 0)
	b.content_margin_left = 14
	b.content_margin_right = 18
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	return b


func _pill(children: Array) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill_box())
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	for c in children:
		h.add_child(c)
	return p


func _label() -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 6)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _picture() -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(64, 64)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t


func toast(text: String) -> void:
	if text == "":
		return
	_toast.text = text
	_toast_t = 2.5


func _process(delta: float) -> void:
	_toast_t -= delta
	_toast_panel.visible = _toast_t > 0.0
	var s := GameSession.current
	if s == null:
		return
	var st := s.stamina.model
	_stamina.max_value = st.max_value()
	_stamina.value = st.current
	var frac := float(st.current) / maxf(1.0, float(st.max_value()))
	var fill := KidTheme.GO if frac > 0.5 else (KidTheme.MONEY if frac > 0.25 else KidTheme.STOP)
	_stamina.add_theme_stylebox_override("fill", KidTheme.box(fill, 12, 0, Color.TRANSPARENT, 0))
	var low := frac <= 0.25
	_stamina.modulate = Color(1, 1, 1, 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 300.0))) if low and not Accessibility.reduce_motion() else Color.WHITE
	var m := GameClock.model.minute
	var hour := (m / 60) % 24
	_day_icon.set_kind(HudIcon.Kind.SUN if hour >= 6 and hour < 20 else HudIcon.Kind.MOON)
	_day.text = "Day %d" % GameClock.model.day
	_coins.text = str(s.wallet.model.coins)
	var unread := s.mail.model.unread_count()
	_mail_pill.visible = unread > 0
	_mail.text = str(unread)
	var equipped := s.toolbelt.model.equipped
	var tool_item: StringName = s.toolbelt.model.owned.get(equipped, &"") if equipped != ToolTypes.NONE else &""
	_tool_pic.get_parent().get_parent().visible = tool_item != &""
	if tool_item != &"":
		_tool_pic.texture = ItemIcons.texture(tool_item)
	var held: Variant = s.hotbar.selected_stack(s.inventory.model)
	_held_pic.get_parent().get_parent().visible = held != null
	if held:
		_held_pic.texture = ItemIcons.texture(held["item_id"])
		_held_qty.text = "x%d" % held["qty"] if int(held["qty"]) > 1 else ""
	_can_pill.visible = equipped == ToolTypes.WATERING_CAN
	_can.max_value = s.farm.model.can_capacity
	_can.value = s.farm.model.can_water
