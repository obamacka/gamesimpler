## In-memory voxel world for tests and graybox scenes (spec 9.7). Cells are a dictionary;
## raycast is a 3D DDA (Amanatides and Woo) over unit cells, matching VoxelTool semantics:
## `cell` is the first solid cell hit, `prev_cell` the empty cell entered just before it.
class_name FakeVoxelWorld
extends IVoxelWorld

var cells: Dictionary = {}          # Vector3i -> int (absent = air)
var unloaded: Dictionary = {}       # Vector3i -> true, for P7 tests


func get_voxel(cell: Vector3i) -> int:
	return cells.get(cell, AIR)


func set_voxel(cell: Vector3i, voxel_id: int) -> void:
	if voxel_id == AIR:
		cells.erase(cell)
	else:
		cells[cell] = voxel_id


func is_loaded(cell: Vector3i) -> bool:
	return not unloaded.has(cell)


func fill(from: Vector3i, to_inclusive: Vector3i, voxel_id: int) -> void:
	for x in range(from.x, to_inclusive.x + 1):
		for y in range(from.y, to_inclusive.y + 1):
			for z in range(from.z, to_inclusive.z + 1):
				set_voxel(Vector3i(x, y, z), voxel_id)


func raycast(origin: Vector3, direction: Vector3, max_distance: float) -> Dictionary:
	if direction.length_squared() == 0.0:
		return {}
	var dir := direction.normalized()
	var cell := IVoxelWorld.cell_of(origin)
	var prev := cell
	var step := Vector3i(int(signf(dir.x)), int(signf(dir.y)), int(signf(dir.z)))
	var t_max := Vector3.ZERO
	var t_delta := Vector3.ZERO
	for i in 3:
		if dir[i] != 0.0:
			var boundary := float(cell[i] + (1 if step[i] > 0 else 0))
			t_max[i] = (boundary - origin[i]) / dir[i]
			t_delta[i] = absf(1.0 / dir[i])
		else:
			t_max[i] = INF
			t_delta[i] = INF
	var t := 0.0
	while t <= max_distance:
		if get_voxel(cell) != AIR:
			return {"cell": cell, "prev_cell": prev, "voxel_id": get_voxel(cell), "distance": t}
		prev = cell
		var axis := 0
		if t_max.y < t_max[axis]:
			axis = 1
		if t_max.z < t_max[axis]:
			axis = 2
		t = t_max[axis]
		t_max[axis] += t_delta[axis]
		cell[axis] += step[axis]
	return {}
