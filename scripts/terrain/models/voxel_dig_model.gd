## Hits, tool fit and partial damage for digging (spec 4.3, 3.4). Pure.
class_name VoxelDigModel
extends RefCounted

const TIER_TOO_LOW := &"tier_too_low"
const NOT_A_DIG_TOOL := &"not_a_dig_tool"
const DAMAGED := &"damaged"
const DUG := &"dug"

var damage: Dictionary = {}   # Vector3i -> hits taken


static func hits_required(mat: VoxelMaterialDef, tool_type: StringName) -> int:
	if tool_type == mat.preferred_tool:
		return mat.hits
	return mat.hits * mat.wrong_tool_hits_multiplier


static func tool_can_dig(mat: VoxelMaterialDef, tool: ToolData) -> StringName:
	if tool == null or not (tool.tool_type in [ToolTypes.SHOVEL, ToolTypes.PICKAXE]):
		return NOT_A_DIG_TOOL
	if tool.tool_type == ToolTypes.PICKAXE and tool.tier < mat.hardness_tier:
		return TIER_TOO_LOW
	if tool.tool_type == ToolTypes.SHOVEL and mat.is_hard() and mat.hardness_tier > 1:
		return TIER_TOO_LOW
	return &""


## One strike. Returns {"result": StringName, "hits_left": int}.
func hit(cell: Vector3i, mat: VoxelMaterialDef, tool: ToolData) -> Dictionary:
	var fit := tool_can_dig(mat, tool)
	if fit != &"":
		return {"result": fit, "hits_left": hits_required(mat, tool.tool_type if tool else &"") - int(damage.get(cell, 0))}
	var need := hits_required(mat, tool.tool_type)
	var taken: int = int(damage.get(cell, 0)) + tool.power
	if taken >= need:
		damage.erase(cell)
		return {"result": DUG, "hits_left": 0}
	damage[cell] = taken
	return {"result": DAMAGED, "hits_left": need - taken}


func daily_reset() -> void:
	damage.clear()


func to_dict() -> Dictionary:
	var d := {}
	for c in damage:
		d["%d,%d,%d" % [c.x, c.y, c.z]] = damage[c]
	return d


func from_dict(d: Dictionary) -> void:
	damage.clear()
	for k in d:
		var p := String(k).split(",")
		damage[Vector3i(int(p[0]), int(p[1]), int(p[2]))] = int(d[k])
