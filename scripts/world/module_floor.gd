## Floor dressing for static rooms (spec 12.8): Village floor modules (2 x 2 m) tiled over a
## rectangle centred on the node, just above the room's collision floor.
class_name ModuleFloor
extends Node3D

@export var piece := "Floor_WoodDark"
@export var tiles := Vector2i(6, 6)


func _ready() -> void:
	var ps := load(ArtPaths.VILLAGE + piece + ".gltf") as PackedScene
	if ps == null:
		return
	for ix in tiles.x:
		for iz in tiles.y:
			var n: Node3D = ps.instantiate()
			n.position = Vector3(-(tiles.x - 1) + 2 * ix, 0.012, -(tiles.y - 1) + 2 * iz)
			add_child(n)
