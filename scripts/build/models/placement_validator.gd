## Piece placement rules (spec 2.7, plan P3.3). Pure: reads a PlacementContext.
## Reasons, in evaluation order: missing_item, outside_plot, occupied, overlaps_player,
## no_support. The pet never invalidates a placement; `nudge_pet` asks the pet to move.
class_name PlacementValidator
extends RefCounted

const OK := &""
const MISSING_ITEM := &"missing_item"
const OUTSIDE_PLOT := &"outside_plot"
const OCCUPIED := &"occupied"
const OVERLAPS_PLAYER := &"overlaps_player"
const NO_SUPPORT := &"no_support"


class PlacementContext:
	var world: IVoxelWorld
	var zone: StringName
	var occupancy: Dictionary = {}     # key -> uid (this zone)
	var pieces: Dictionary = {}        # uid -> instance {"piece_id", "state", ...}
	var plots: Array = []              # owned PlotDefs
	var player_cells: Array = []
	var pet_cells: Array = []
	var has_item := true
	var protected: Callable = func(_c: Vector3i) -> bool: return false


static func validate(ctx: PlacementContext, def: BuildPieceDef, anchor: Vector3i, r: int) -> Dictionary:
	var occ := BuildGrid.occupancy(def, anchor, r)
	var cells: Array[Vector3i] = []
	for o in occ:
		cells.append(o["cell"])
	var res := {"ok": false, "reason": OK, "cells": cells, "nudge_pet": false}
	if not ctx.has_item:
		res["reason"] = MISSING_ITEM
		return res
	if not in_owned_plot(ctx, cells):
		res["reason"] = OUTSIDE_PLOT
		return res
	for o in occ:
		var c: Vector3i = o["cell"]
		if ctx.occupancy.has(o["key"]) or ctx.world.get_voxel(c) != IVoxelWorld.AIR or ctx.protected.call(c):
			res["reason"] = OCCUPIED
			return res
	for c in cells:
		if c in ctx.player_cells:
			res["reason"] = OVERLAPS_PLAYER
			return res
	if def.requires_support and not is_supported(ctx, def, cells):
		res["reason"] = NO_SUPPORT
		return res
	for c in cells:
		if c in ctx.pet_cells:
			res["nudge_pet"] = true
	res["ok"] = true
	return res


static func in_owned_plot(ctx: PlacementContext, cells: Array) -> bool:
	for c in cells:
		var inside := false
		for p in ctx.plots:
			if (p as PlotDef).contains(ctx.zone, c):
				inside = true
				break
		if not inside:
			return false
	return true


## Support (spec 2.7): a solid voxel below, or a FASTENED provides_support piece below or as
## the floor slab of the same cell (walls and furniture stand on floors). LOOSE never supports.
## At least one bottom cell of the footprint must be supported.
static func is_supported(ctx: PlacementContext, def: BuildPieceDef, cells: Array[Vector3i]) -> bool:
	for c in cells:
		if (c + Vector3i.DOWN) in cells:
			continue
		if ctx.world.get_voxel(c + Vector3i.DOWN) != IVoxelWorld.AIR:
			return true
		if def.layer != BuildPieceDef.LAYER_FLOOR and _supports(ctx, BuildGrid.cell_key("f", c)):
			return true
		for k in BuildGrid.keys_touching(c + Vector3i.DOWN):
			if _supports(ctx, k):
				return true
	return false


static func _supports(ctx: PlacementContext, key: String) -> bool:
	if not ctx.occupancy.has(key):
		return false
	var inst: Dictionary = ctx.pieces.get(ctx.occupancy[key], {})
	if inst.is_empty() or inst.get("state", &"") != &"FASTENED":
		return false
	var d: BuildPieceDef = Database.pieces.get(StringName(inst["piece_id"]))
	return d != null and d.provides_support
