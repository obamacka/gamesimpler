## Inventory service (spec 1.8): wraps InventoryModel and emits events.
class_name InventoryService
extends Node

var model := InventoryModel.new()


## Adds items; returns overflow. Emits item_added for the amount actually added.
func add(item_id: StringName, qty: int, data: Dictionary = {}) -> int:
	var overflow := model.add(item_id, qty, data)
	if qty - overflow > 0:
		EventBus.item_added.emit(item_id, qty - overflow)
		EventBus.inventory_changed.emit()
	return overflow


func remove(item_id: StringName, qty: int) -> bool:
	if model.remove(item_id, qty):
		EventBus.inventory_changed.emit()
		return true
	return false


func count(item_id: StringName) -> int:
	return model.count(item_id)
