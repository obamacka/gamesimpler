## Phase 2 HUD: stamina bar with low pulses, clock, coins, equipped tool, unread mail, toasts.
## Phase 2B: watering-can level and the selected hotbar slot (Phase 4 replaces this with the hotbar UI).
extends CanvasLayer

var _stamina: ProgressBar
var _info: Label
var _toast: Label
var _toast_t := 0.0


func _ready() -> void:
	var v := VBoxContainer.new()
	v.position = Vector2(24, 24)
	add_child(v)
	_stamina = ProgressBar.new()
	_stamina.custom_minimum_size = Vector2(260, 22)
	_stamina.show_percentage = false
	v.add_child(_stamina)
	_info = Label.new()
	v.add_child(_info)
	_toast = Label.new()
	_toast.position = Vector2(860, 120)
	add_child(_toast)
	EventBus.stamina_low.connect(func(pct): toast("Feeling tired (%d%%)" % pct))
	EventBus.prompt_changed.connect(func(_k, state, _t): toast(PromptModel.BLOCKED_TEXT.get(state, "")))
	EventBus.mail_delivered.connect(func(_ids): toast("Mail arrived"))
	EventBus.chest_opened.connect(func(_k, r): toast("Treasure: %s" % (r["id"] if r["id"] != &"" else ("%d coins" % r["coins"] if r["coins"] > 0 else r["item"]))))
	EventBus.stuck_hint.connect(func(): toast("Stuck? Try Go Home from the pause menu"))
	EventBus.crop_harvested.connect(func(_c, crop_id, qty): toast("Harvested %d %s" % [qty, String(crop_id).trim_prefix("crop_")]))
	EventBus.can_refilled.connect(func(_w): toast("Watering can full"))


func toast(text: String) -> void:
	if text == "":
		return
	_toast.text = text
	_toast_t = 2.5


func _process(delta: float) -> void:
	var s := GameSession.current
	if s == null:
		return
	var st := s.stamina.model
	_stamina.max_value = st.max_value()
	_stamina.value = st.current
	var low := st.current * 100 <= st.max_value() * 25
	_stamina.modulate = Color(1, 0.6, 0.6, 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 300.0))) if low else Color.WHITE
	var m := GameClock.model.minute
	var held := s.hotbar.selected_stack(s.inventory.model)
	_info.text = "Day %d  %02d:%02d\nCoins %d   Tool %s   Mail %d\nCan %d/%d   Hand %d: %s" % [GameClock.model.day, (m / 60) % 24, m % 60,
		s.wallet.model.coins, String(s.toolbelt.model.equipped) if s.toolbelt.model.equipped != &"" else "hands",
		s.mail.model.unread_count(), s.farm.model.can_water, s.farm.model.can_capacity, s.hotbar.selected + 1,
		"%s x%d" % [held["item_id"], held["qty"]] if held else "empty"]
	_toast_t -= delta
	_toast.visible = _toast_t > 0.0
