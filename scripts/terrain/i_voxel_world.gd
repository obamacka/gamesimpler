## The only interface gameplay uses to touch terrain (spec 9.1, 9.7).
## Voxel id 0 is air. Implementations: VoxelWorldAdapter (Voxel Tools), FakeVoxelWorld (tests).
class_name IVoxelWorld
extends RefCounted

const AIR := 0


func get_voxel(_cell: Vector3i) -> int:
	return AIR


func set_voxel(_cell: Vector3i, _voxel_id: int) -> void:
	pass


func is_loaded(_cell: Vector3i) -> bool:
	return true


## Returns {} on miss, else {"cell": Vector3i, "prev_cell": Vector3i, "voxel_id": int, "distance": float}.
func raycast(_origin: Vector3, _direction: Vector3, _max_distance: float) -> Dictionary:
	return {}


static func cell_of(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x), floori(p.y), floori(p.z))
