## Voxel material (spec 3.4). voxel_id is the model index in the VoxelBlockyLibrary.
class_name VoxelMaterialDef
extends Resource

const SPECIAL_NONE := &"NONE"
const SPECIAL_GEODE := &"GEODE"
const SPECIAL_CHEST := &"CHEST"
const SPECIAL_BEDROCK := &"BEDROCK"

@export var id: StringName
@export var voxel_id := 0
@export var hardness_tier := 1
@export var hits := 1
@export var wrong_tool_hits_multiplier := 2
@export var preferred_tool: StringName = &"SHOVEL"
@export var drop: StringName = &""          # LootTableDef id
@export var special: StringName = SPECIAL_NONE
@export var placeable := false
@export var stamina_cost := 1
@export var color := Color.WHITE


## Soft materials are dug with the shovel, hard ones with the pickaxe (spec 2.6).
func is_hard() -> bool:
	return preferred_tool == ToolTypes.PICKAXE
## Block tiles (spec 11.10): {"top", "side", "bottom"} file names in the Voxel Pack folder; side
## stands in for missing entries. tint multiplies the tiles.
@export var tiles: Dictionary = {}
@export var tint := Color.WHITE


func tile(face: String) -> String:
	return String(tiles.get(face, tiles.get("side", "")))
