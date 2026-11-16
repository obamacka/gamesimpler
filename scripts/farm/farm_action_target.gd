## Stand-in interact target for farm actions (spec 10.4, plan P2B.7). The player points it at
## the aimed farm cell each tick; the Interact state uses it like an Interactable.
class_name FarmActionTarget
extends Node3D

const DURATIONS := {&"till": 0.4, &"plant": 0.2, &"water": 0.3, &"refill": 0.3, &"harvest": 0.3, &"place_sprinkler": 0.3}

var action: Dictionary = {}


func configure(a: Dictionary, pos: Vector3) -> void:
	action = a
	if is_inside_tree():
		global_position = pos


func has_action() -> bool:
	return not action.is_empty()


func spec_for(_player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	if action.is_empty() or alt:
		return null
	var kind: StringName = action["action"]
	return InteractionSpec.new(StringName(String(kind).to_upper()), DURATIONS.get(kind, 0.3))


func resolve(_spec: InteractionSpec, _player: Node) -> void:
	var s := GameSession.current
	if s and not action.is_empty():
		s.farm.execute(action.duplicate())
