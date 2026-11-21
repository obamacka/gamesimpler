## Solid building exterior (spec 12.3): `model` fitted into `size` with a collider of the
## fitted size; without a model, a coloured box.
class_name BuildingShell
extends WorldObject

@export var size := Vector3(6, 4, 6)
@export var color := Color(0.55, 0.35, 0.2)
@export_file("*.gltf", "*.glb", "*.fbx", "*.tscn") var model := ""
@export var model_yaw_deg := 0
## Non-zero: show the model at this fixed scale with its own pivot (spec 12.8, assembled houses).
@export var model_scale := 0.0

var art: Node3D


func _ready() -> void:
	if model_scale > 0.0:
		art = add_art_at(self, model, model_scale, model_yaw_deg)
	else:
		art = add_art(self, model, AABB(Vector3(-size.x * 0.5, 0, -size.z * 0.5), size), model_yaw_deg)
	if art:
		var b := art_collision(art)
		add_static_box(self, b.size, b.get_center())
		return
	add_child(box_mesh(size, color, Vector3(0, size.y * 0.5, 0)))
	add_static_box(self, size, Vector3(0, size.y * 0.5, 0))
