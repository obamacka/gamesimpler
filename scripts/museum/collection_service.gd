## Collection Book (spec 6.5): marks collectibles discovered on item_added, once per id.
class_name CollectionService
extends Node

var session: GameSession
var model := CollectionModel.new()


func setup(s: GameSession) -> void:
	session = s


func _ready() -> void:
	EventBus.item_added.connect(_on_item_added)


func _exit_tree() -> void:
	if EventBus.item_added.is_connected(_on_item_added):
		EventBus.item_added.disconnect(_on_item_added)


func _on_item_added(item_id: StringName, _qty: int) -> void:
	mark_discovered(item_id)


func mark_discovered(item_id: StringName) -> bool:
	if model.mark(item_id):
		EventBus.entry_discovered.emit(item_id)
		return true
	return false
