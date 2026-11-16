## Owned tools, one active per type (highest tier), and the equipped type (spec 2.6).
class_name ToolBeltModel
extends RefCounted

var owned: Dictionary = {}          # StringName tool_type -> StringName item_id
var equipped: StringName = ToolTypes.NONE
var item_lookup: Callable


func _init(lookup: Callable = Callable()) -> void:
	item_lookup = lookup if lookup.is_valid() else func(id): return Database.item(id)


## Grants a TOOL item. Keeps the higher tier if one is already owned. Returns true if it changed.
func grant(item_id: StringName) -> bool:
	var it: ItemDef = item_lookup.call(item_id)
	if it == null or it.tool == null:
		return false
	var t := it.tool.tool_type
	if owned.has(t):
		var cur: ItemDef = item_lookup.call(owned[t])
		if cur and cur.tool.tier >= it.tool.tier:
			return false
	owned[t] = item_id
	return true


func remove_type(tool_type: StringName) -> void:
	owned.erase(tool_type)
	if equipped == tool_type:
		equipped = ToolTypes.NONE


func has_tool(tool_type: StringName) -> bool:
	return owned.has(tool_type)


func tool_data(tool_type: StringName) -> ToolData:
	if not owned.has(tool_type):
		return null
	var it: ItemDef = item_lookup.call(owned[tool_type])
	return it.tool if it else null


func equipped_data() -> ToolData:
	return tool_data(equipped)


func equip(tool_type: StringName) -> bool:
	if not owned.has(tool_type):
		return false
	equipped = tool_type
	return true


func unequip() -> void:
	equipped = ToolTypes.NONE


func to_dict() -> Dictionary:
	var d := {}
	for t in owned:
		d[String(t)] = String(owned[t])
	return d


func from_dict(d: Dictionary) -> void:
	owned.clear()
	for t in d:
		owned[StringName(t)] = StringName(d[t])
	equipped = ToolTypes.NONE
