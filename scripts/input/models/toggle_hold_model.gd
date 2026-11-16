## Toggle-or-hold activation for run and duck (spec 2.2, 5.10).
class_name ToggleHoldModel
extends RefCounted

const TOGGLE := &"toggle"
const HOLD := &"hold"

var mode: StringName = TOGGLE
var active := false


func _init(start_mode: StringName = TOGGLE) -> void:
	mode = start_mode


## Call once per physics tick with the action's press edge and held state.
func update(pressed: bool, held: bool) -> bool:
	if mode == HOLD:
		active = held
	elif pressed:
		active = not active
	return active


func reset() -> void:
	active = false
