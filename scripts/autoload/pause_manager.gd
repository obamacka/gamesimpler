## Sole writer of get_tree().paused (spec 5.2). Pause requests are ref-counted by reason;
## signals fire only on the 0 -> 1 and 1 -> 0 edges.
extends Node

const MENU := &"menu"
const TRANSITION := &"transition"
const FOCUS_LOST := &"focus_lost"
const DEVICE_LOST := &"device_lost"

var _reasons: Dictionary = {}   # StringName -> true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func request_pause(reason: StringName) -> void:
	if _reasons.has(reason):
		return
	var was_paused := is_paused()
	_reasons[reason] = true
	if not was_paused:
		_apply(true)


func release_pause(reason: StringName) -> void:
	if not _reasons.has(reason):
		return
	_reasons.erase(reason)
	if _reasons.is_empty():
		_apply(false)


func has_reason(reason: StringName) -> bool:
	return _reasons.has(reason)


func is_paused() -> bool:
	return not _reasons.is_empty()


func reasons() -> Array:
	return _reasons.keys()


## Releases every reason and unpauses (returning to the title screen, spec 12.1).
func release_all() -> void:
	reset_for_tests()


## Releases every reason and unpauses. Call in after_test so a failing test cannot
## leave the tree paused for the next one (spec 0.6 item 15).
func reset_for_tests() -> void:
	var was_paused := is_paused()
	_reasons.clear()
	if was_paused:
		_apply(false)
	else:
		get_tree().paused = false


func _apply(paused: bool) -> void:
	get_tree().paused = paused
	if paused:
		EventBus.game_paused.emit()
	else:
		EventBus.game_resumed.emit()
	EventBus.pause_changed.emit(paused, reasons())
