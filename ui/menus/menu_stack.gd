## Menu stack (spec 5.3, plan P3.10). ALWAYS. The first push requests the `menu` pause; the
## last pop releases it (deferred) and arms the player's resume guard. Pushes are refused
## during a `transition` pause. Phase 4 adds the global keys pause_menu / open_inventory.
class_name MenuStack
extends CanvasLayer

static var instance: MenuStack

const MENUS := {
	&"confirm": "res://ui/menus/confirm_menu.gd",
	&"build_catalog": "res://ui/menus/build_catalog.gd",
}

var registry: Dictionary = MENUS.duplicate()
var _stack: Array[MenuBase] = []
var _focus_memory: Array = []   # focus owner to restore per stacked menu
var _mouse_before := Input.MOUSE_MODE_VISIBLE


func _enter_tree() -> void:
	instance = self
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if instance == self:
		instance = null


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
		f.grab_focus.call_deferred()
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
			(restore as Control).grab_focus.call_deferred()
	if cb.is_valid():
		cb.call(res)


func pop_to(menu_id: StringName) -> void:
	while not _stack.is_empty() and top().menu_id != menu_id:
		pop()


func close_all() -> void:
	while not _stack.is_empty():
		pop()


func _unhandled_input(event: InputEvent) -> void:
	if _stack.is_empty():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		top().on_cancel()
