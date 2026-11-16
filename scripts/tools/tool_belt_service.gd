## Tool belt service (spec 1.8): owned tools and the equipped one.
class_name ToolBeltService
extends Node

var model := ToolBeltModel.new()


func grant(item_id: StringName) -> bool:
	return model.grant(item_id)


func equip(tool_type: StringName, source: StringName) -> bool:
	if not model.equip(tool_type):
		return false
	EventBus.tool_equipped.emit(tool_type, model.owned[tool_type], source)
	return true


func unequip(source: StringName) -> void:
	if model.equipped == ToolTypes.NONE:
		return
	model.unequip()
	EventBus.tool_unequipped.emit(source)
