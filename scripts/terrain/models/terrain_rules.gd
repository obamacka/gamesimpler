## Dig and place protection (spec 9.3, P1 to P7). Pure apart from reading IVoxelWorld.
## Evaluated in spec order; the first failing rule's reason is returned.
class_name TerrainRules
extends RefCounted

const OK := &""
const PROTECTED := &"protected"
const BEDROCK := &"bedrock"
const SUPPORTS_OBJECT := &"supports_object"
const SUPPORTS_BUILDING := &"supports_building"
const JOB_SITE := &"job_site"
const UNDER_PLAYER := &"under_player"
const INSIDE_PLAYER := &"inside_player"
const INSIDE_PET := &"inside_pet"
const NOT_LOADED := &"not_loaded"
const EMPTY := &"empty"
const OCCUPIED := &"occupied"

var world: IVoxelWorld
## [{"min": Vector3i, "max": Vector3i (inclusive), "reason": StringName, "allows_place": bool}]
var volumes: Array = []
var support_cells: Dictionary = {}       # Vector3i -> object key (trees, interactables, spawns)
var bounds_min_y := -32
var bedrock_voxel := -1
var player_feet_cell := Vector3i(0, -100000, 0)
var player_cells: Array[Vector3i] = []
var pet_cells: Array[Vector3i] = []
var occupied_cells: Dictionary = {}      # Vector3i -> object key (crops, sprinklers: spec 10.6)
## Phase 3 hooks (build pieces). Default: nothing built.
var building_supported: Callable = func(_c: Vector3i) -> bool: return false
var piece_occupied: Callable = func(_c: Vector3i) -> bool: return false


func _init(w: IVoxelWorld = null) -> void:
	world = w


func add_volume(min_cell: Vector3i, max_cell: Vector3i, reason: StringName = &"TOWN", allows_place: bool = false) -> void:
	volumes.append({"min": min_cell, "max": max_cell, "reason": reason, "allows_place": allows_place})


## Protects the cell under an object's base and its 8 horizontal neighbors (P3).
func protect_support(base_cell: Vector3i, key: String, neighbors: bool = true) -> void:
	var below := base_cell + Vector3i.DOWN
	if not neighbors:
		support_cells[below] = key
		return
	for x in range(-1, 2):
		for z in range(-1, 2):
			support_cells[below + Vector3i(x, 0, z)] = key


func release_support(key: String) -> void:
	for c in support_cells.keys():
		if support_cells[c] == key:
			support_cells.erase(c)


func _volume_at(cell: Vector3i) -> Dictionary:
	for v in volumes:
		var a: Vector3i = v["min"]
		var b: Vector3i = v["max"]
		if cell.x >= a.x and cell.x <= b.x and cell.y >= a.y and cell.y <= b.y and cell.z >= a.z and cell.z <= b.z:
			return v
	return {}


## P1 only: inside a protection volume that refuses this kind of edit.
func is_protected(cell: Vector3i, for_place: bool) -> bool:
	var vol := _volume_at(cell)
	return not vol.is_empty() and vol["reason"] != &"JOB_SITE" and not (for_place and vol["allows_place"])


func can_dig(cell: Vector3i) -> StringName:
	var vol := _volume_at(cell)
	if not vol.is_empty() and vol["reason"] != &"JOB_SITE":
		return PROTECTED                                               # P1
	if cell.y < bounds_min_y or (bedrock_voxel >= 0 and world.get_voxel(cell) == bedrock_voxel):
		return BEDROCK                                                  # P2
	if support_cells.has(cell):
		return SUPPORTS_OBJECT                                          # P3
	if building_supported.call(cell):
		return SUPPORTS_BUILDING                                        # P4
	if not vol.is_empty():
		return JOB_SITE                                                 # P5
	if cell == player_feet_cell:
		return UNDER_PLAYER                                             # P6
	if not world.is_loaded(cell):
		return NOT_LOADED                                               # P7
	if world.get_voxel(cell) == IVoxelWorld.AIR:
		return EMPTY
	return OK


func can_place(cell: Vector3i) -> StringName:
	var vol := _volume_at(cell)
	if not vol.is_empty() and vol["reason"] != &"JOB_SITE" and not vol["allows_place"]:
		return PROTECTED                                                # P1
	if cell.y < bounds_min_y:
		return BEDROCK                                                  # P2
	if world.get_voxel(cell) != IVoxelWorld.AIR or piece_occupied.call(cell) or occupied_cells.has(cell):
		return OCCUPIED
	if not vol.is_empty() and vol["reason"] == &"JOB_SITE":
		return JOB_SITE                                                 # P5
	if cell in player_cells:
		return INSIDE_PLAYER                                            # P6
	if cell in pet_cells:
		return INSIDE_PET                                               # P6
	if not world.is_loaded(cell):
		return NOT_LOADED                                               # P7
	return OK
