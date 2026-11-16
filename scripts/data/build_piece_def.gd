## Build piece (spec 3.4). Occupancy is per cell and layer (spec 1.6, rev 3.6): FLOOR slabs,
## BODY pieces (furniture, stairs) and WALL pieces that sit on a cell edge. Positions are
## local to the anchor cell's origin in the unrotated frame; rotation is about the anchor
## cell's vertical center line in 90-degree steps.
class_name BuildPieceDef
extends Resource

const LAYER_FLOOR := &"FLOOR"
const LAYER_BODY := &"BODY"
const LAYER_WALL := &"WALL"
const GRID_STRUCTURE := &"STRUCTURE_1M"
const GRID_FURNITURE := &"FURNITURE_0_5M"
const NONE := &"NONE"
const NAILS := &"NAILS"
const SCREWS := &"SCREWS"

@export var id: StringName
@export var item_id: StringName
@export var layer: StringName = LAYER_BODY
@export var grid: StringName = GRID_STRUCTURE
@export var footprint: Array[Vector3i] = [Vector3i.ZERO]
@export var opening: Array[Vector3i] = []        # cells a door leaves free
@export var fastener: StringName = NONE
@export var hits_per_socket := 0
@export var fastener_sockets: Array[Vector3] = []
@export var requires_support := true
@export var provides_support := false
@export var accepts: Array[StringName] = []
## [{"position": Vector3, "provides": StringName, "attach_offset": Vector3i, "attach_rot": int}]
@export var snap_sockets: Array = []
## [{"kind": StringName, ...}] SIT: seats, exits, stamina_regen_per_sec; TOGGLE: toggle_states; SLEEP; STORAGE: slots
@export var interactions: Array = []
## [{"size": Vector3, "center": Vector3, "solid": bool}] placeholder geometry
@export var parts: Array = []
@export var color := Color.WHITE
## [{"region_id": PRIMARY|SECONDARY|TRIM, "shader_param": StringName, "default_dye_id"}] (max 3)
@export var paint_regions: Array = []
@export var stampable := false


func region_param(region_id: StringName) -> StringName:
	for r in paint_regions:
		if r["region_id"] == region_id:
			return r["shader_param"]
	return &""


func is_furniture() -> bool:
	return grid == GRID_FURNITURE


func needs_fastening() -> bool:
	return fastener != NONE and not fastener_sockets.is_empty()


func interaction(kind: StringName) -> Dictionary:
	for i in interactions:
		if i["kind"] == kind:
			return i
	return {}
