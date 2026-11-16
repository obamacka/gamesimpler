class_name UnlockService
extends Node

var model := UnlockModel.new()


func grant(kind: StringName, id: StringName) -> bool:
	if model.grant(kind, id):
		EventBus.unlock_granted.emit(kind, id)
		return true
	return false
