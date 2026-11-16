## In-game clock (spec 1.2, D6). Pausable: time stops in menus and transitions.
## `running` is off until a session starts play, so tests control time explicitly.
extends Node

var model := GameClockModel.new()
var running := false


func _process(delta: float) -> void:
	if running and model.tick(delta):
		EventBus.clock_late_night.emit()
