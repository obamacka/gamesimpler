class_name DiscoveryService
extends Node

var model := DiscoveryModel.new()


func _ready() -> void:
	model.configure(Database.discovery)
