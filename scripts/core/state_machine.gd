## Generic FSM (spec 4.1). States are the child nodes; their node names, lowercased,
## are the state ids (e.g. "Idle" -> &"idle"). Exactly one state is active.
class_name StateMachine
extends Node

signal transitioned(from: StringName, to: StringName)

@export var initial_state: StringName = &"idle"

var states: Dictionary = {}   # StringName -> State
var current: State
var current_id: StringName = &""


func _ready() -> void:
	for child in get_children():
		if child is State:
			var id := StringName(String(child.name).to_lower())
			states[id] = child
			child.machine = self
	if states.has(initial_state):
		current_id = initial_state
		current = states[initial_state]
		current.enter({})


func has_state(id: StringName) -> bool:
	return states.has(id)


## Exits the current state and enters `to`. Re-entering the same state is allowed
## (used for the double jump) and still calls exit/enter exactly once each.
func transition_to(to: StringName, msg: Dictionary = {}) -> void:
	assert(states.has(to), "StateMachine: unknown state %s" % to)
	var from := current_id
	if current:
		current.exit()
	current_id = to
	current = states[to]
	current.enter(msg)
	transitioned.emit(from, to)
