## Placeholder solid building exterior (a box with collision). Final art replaces it.
class_name BuildingShell
extends WorldObject

@export var size := Vector3(6, 4, 6)
@export var color := Color(0.55, 0.35, 0.2)


func _ready() -> void:
	add_child(box_mesh(size, color, Vector3(0, size.y * 0.5, 0)))
	add_static_box(self, size, Vector3(0, size.y * 0.5, 0))
