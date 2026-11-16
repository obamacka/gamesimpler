## Base for player FSM states (spec 4.2). States are thin: the transition table decides,
## the controller moves the body; a state supplies its speed and entry/exit effects.
class_name PlayerState
extends State

var player: PlayerController


func is_airborne() -> bool:
	return false


func move_speed() -> float:
	return 0.0


## Called every physics tick while this state is active, before movement.
func physics_tick(_delta: float, _f: InputFrame) -> void:
	pass


## True while the state holds the auto-tool lock (spec 2.6 rule 5).
func locks_tool() -> bool:
	return false
