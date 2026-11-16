## IVoxelWorld over a Voxel Tools VoxelTerrain (spec 9.1). Uses only verified VoxelTool API:
## get_voxel, set_voxel, raycast (VoxelRaycastResult.position / previous_position / distance),
## is_area_editable.
class_name VoxelWorldAdapter
extends IVoxelWorld

var terrain: VoxelTerrain
var _tool: VoxelTool


func _init(t: VoxelTerrain) -> void:
	terrain = t
	_tool = t.get_voxel_tool()
	_tool.channel = VoxelBuffer.CHANNEL_TYPE


func get_voxel(cell: Vector3i) -> int:
	return _tool.get_voxel(cell)


func set_voxel(cell: Vector3i, voxel_id: int) -> void:
	_tool.set_voxel(cell, voxel_id)


func is_loaded(cell: Vector3i) -> bool:
	return _tool.is_area_editable(AABB(Vector3(cell), Vector3.ONE))


func raycast(origin: Vector3, direction: Vector3, max_distance: float) -> Dictionary:
	var hit: VoxelRaycastResult = _tool.raycast(origin, direction.normalized(), max_distance)
	if hit == null:
		return {}
	return {"cell": hit.position, "prev_cell": hit.previous_position, "voxel_id": _tool.get_voxel(hit.position), "distance": hit.distance}
