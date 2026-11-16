## Pet pathing on voxel ground (spec 9.4): VoxelAStarGrid3D over a 32x16x32 region centered
## on the player, re-centered after the player moves 8 m.
class_name VoxelPathProvider
extends PetPathProvider

const REGION := Vector3i(32, 16, 32)

var grid: VoxelAStarGrid3D
var center := Vector3(INF, INF, INF)


func _init(terrain: Node) -> void:
	grid = VoxelAStarGrid3D.new()
	grid.set_terrain(terrain)


func recenter(player_pos: Vector3) -> void:
	if center.distance_to(player_pos) < 8.0:
		return
	center = player_pos
	var c := IVoxelWorld.cell_of(player_pos)
	grid.set_region(AABB(Vector3(c - REGION / 2), Vector3(REGION)))


func find_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	if fail:
		return []
	recenter(to)
	var cells: Array = grid.find_path(IVoxelWorld.cell_of(from), IVoxelWorld.cell_of(to))
	var out: Array[Vector3] = []
	for c in cells:
		out.append(Vector3(c) + Vector3(0.5, 0.0, 0.5))
	return out
