## Base FSM state (spec 4.1). Concrete states override the hooks.
class_name State
extends Node

## Set by StateMachine when the state is registered.
var machine: StateMachine


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass
