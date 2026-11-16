## Menu stack (spec 5.3, P3.10, P4.10). ALWAYS. The first push requests the `menu` pause; the
## last pop releases it (deferred) and arms the player's resume guard. Pushes are refused
## during a `transition` pause. Global keys: pause_menu, ui_cancel, open_inventory. Also the
## automatic pause triggers (spec 5.6): focus loss and active pad loss (with DeviceBanner).
class_name MenuStack
extends CanvasLayer

static var instance: MenuStack

const MENUS := {
	&"confirm": "res://ui/menus/confirm_menu.gd",
	&"go_home_confirm": "res://ui/menus/confirm_menu.gd",
	&"mine_entrance_confirm": "res://ui/menus/confirm_menu.gd",
	&"build_catalog": "res://ui/menus/build_catalog.gd",
	&"pause_menu": "res://ui/menus/pause_menu.gd",
	&"settings": "res://ui/menus/settings_menu.gd",
	&"rebind_capture": "res://ui/menus/rebind_capture.gd",
	&"inventory": "res://ui/menus/inventory_menu.gd",
	&"shop": "res://ui/menus/shop_menu.gd",
	&"job_board": "res://ui/menus/job_board.gd",
	&"crafting": "res://ui/menus/crafting_menu.gd",
	&"house_purchase": "res://ui/menus/house_purchase.gd",
	&"outfit_customizer": "res://ui/menus/outfit_customizer.gd",
	&"storage": "res://ui/menus/storage_menu.gd",
	&"dialogue": "res://ui/menus/dialogue_menu.gd",
	&"gift_picker": "res://ui/menus/gift_picker.gd",
	&"mail": "res://ui/menus/mail_menu.gd",
	&"pet_adoption": "res://ui/menus/pet_adoption.gd",
	&"pet_wardrobe": "res://ui/menus/pet_wardrobe.gd",
	&"wheel": "res://ui/menus/wheel_menu.gd",
}

var registry: Dictionary = MENUS.duplicate()
var _stack: Array[MenuBase] = []
var _focus_memory: Array = []   # focus owner to restore per stacked menu
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var banner: Label


func _enter_tree() -> void:
	instance = self
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	banner = Label.new()
	banner.name = "DeviceBanner"
	banner.text = "Controller disconnected. Reconnect it to keep playing."
	banner.position = Vector2(40, 20)
	banner.visible = false
	add_child(banner)
	EventBus.joypad_lost.connect(_on_joypad_lost)
	EventBus.joypad_restored.connect(_on_joypad_restored)


func _exit_tree() -> void:
	if instance == self:
		instance = null
	for pair in [[EventBus.joypad_lost, _on_joypad_lost], [EventBus.joypad_restored, _on_joypad_restored]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func register(menu_id: StringName, script_path: String) -> void:
	registry[menu_id] = script_path


func is_open() -> bool:
	return not _stack.is_empty()


func top() -> MenuBase:
	return _stack.back() if not _stack.is_empty() else null


func depth() -> int:
	return _stack.size()


func push(menu_id: StringName, args: Dictionary = {}) -> MenuBase:
	if PauseManager.has_reason(PauseManager.TRANSITION):
		return null
	if not registry.has(menu_id):
		push_warning("MenuStack: unknown menu %s" % menu_id)
		return null
	var m: MenuBase = (load(registry[menu_id]) as GDScript).new()
	m.menu_id = menu_id
	m.args = args
	m.name = String(menu_id)
	m.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var first := _stack.is_empty()
	_focus_memory.append(get_viewport().gui_get_focus_owner())
	if first:
		_mouse_before = Input.mouse_mode
		PauseManager.request_pause(PauseManager.MENU)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif top():
		top().visible = false
	_stack.append(m)
	add_child(m)
	m.build()
	var f := m.initial_focus()
	if f:
		MenuBase.focus_later(f)
	if OS.is_debug_build():
		for prob in m.focus_problems():
			push_warning("MenuStack: %s has an unfocusable button %s" % [menu_id, prob])
	EventBus.menu_opened.emit(menu_id)
	return m


func pop() -> void:
	if _stack.is_empty():
		return
	var m: MenuBase = _stack.pop_back()
	var restore = _focus_memory.pop_back()
	var cb: Callable = m.args.get("on_close", Callable())
	var id := m.menu_id
	var res = m.result
	remove_child(m)
	m.queue_free()
	EventBus.menu_closed.emit(id)
	if _stack.is_empty():
		Input.mouse_mode = _mouse_before
		var p := SceneRouter.player
		if is_instance_valid(p) and p.has_method("arm_resume_guard"):
			p.arm_resume_guard()
		PauseManager.release_pause.call_deferred(PauseManager.MENU)
	else:
		top().visible = true
		if is_instance_valid(restore) and restore is Control:
			MenuBase.focus_later(restore as Control)
	if cb.is_valid():
		cb.call(res)


## Runs `fn` once the menu pause has been released (the release is deferred).
func after_resume(fn: Callable) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	fn.call()


func pop_to(menu_id: StringName) -> void:
	while not _stack.is_empty() and top().menu_id != menu_id:
		pop()


func close_all() -> void:
	while not _stack.is_empty():
		pop()


func _unhandled_input(event: InputEvent) -> void:
	if handle_global(event):
		get_viewport().set_input_as_handled()


## Global menu keys (spec 5.3). In menus ui_cancel is checked first (Esc is both). Public so
## tests can feed InputEventAction objects.
func handle_global(event: InputEvent) -> bool:
	if not _stack.is_empty():
		if event.is_action_pressed(&"ui_cancel"):
			top().on_cancel()
			return true
		if event.is_action_pressed(&"pause_menu"):
			close_all()
			return true
		if event.is_action_pressed(&"open_inventory") and top().menu_id == &"inventory":
			pop()
			return true
		return false
	if not _gameplay_ready():
		return false
	if event.is_action_pressed(&"pause_menu"):
		return push(&"pause_menu") != null
	if event.is_action_pressed(&"open_inventory"):
		return push(&"inventory") != null
	return false


func _gameplay_ready() -> bool:
	return GameSession.current != null and is_instance_valid(SceneRouter.player)


## Focus recovery (spec 5.9): if focus is lost while a menu is open, return it to the menu.
func _process(_delta: float) -> void:
	if not _stack.is_empty() and get_viewport().gui_get_focus_owner() == null:
		var f := top().initial_focus()
		if f and f.is_visible_in_tree():
			f.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		on_focus_lost()


## Window focus lost (spec 5.6): open the pause menu if nothing is open.
func on_focus_lost() -> void:
	if _stack.is_empty() and _gameplay_ready():
		push(&"pause_menu")


func _on_joypad_lost(_device: int) -> void:
	PauseManager.request_pause(PauseManager.DEVICE_LOST)
	banner.visible = true
	if _stack.is_empty() and _gameplay_ready():
		push(&"pause_menu")


func _on_joypad_restored(_device: int) -> void:
	if banner.visible:
		banner.visible = false
		PauseManager.release_pause(PauseManager.DEVICE_LOST)
