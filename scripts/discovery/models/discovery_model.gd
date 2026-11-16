## Geodes and buried treasure from digging (spec 6.4). Deterministic through RngStreams.
class_name DiscoveryModel
extends RefCounted

const NEIGHBORS: Array[Vector3i] = [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]

var geode_pity_limit := 40
var chest_pity_limit := 150
var pity_geode := 0
var pity_chest := 0


func configure(cfg: DiscoveryConfig) -> void:
	geode_pity_limit = cfg.geode_pity
	chest_pity_limit = cfg.chest_pity


## Called after a voxel at `cell` with material `mat` was dug (already air in `world`).
## Returns {"extra_geode": bool, "chest_cells": Array[Vector3i]}. Chest blocks found at the
## cell or its 6 neighbors are converted to air and reported, so the caller spawns chests.
func on_voxel_dug(mat: VoxelMaterialDef, cell: Vector3i, world: IVoxelWorld, chest_voxel: int) -> Dictionary:
	var extra_geode := false
	if mat.special == VoxelMaterialDef.SPECIAL_GEODE:
		pity_geode = 0
	elif mat.is_hard():
		pity_geode += 1
		if pity_geode >= geode_pity_limit:
			extra_geode = true
			pity_geode = 0
	var chests: Array[Vector3i] = []
	if mat.special == VoxelMaterialDef.SPECIAL_CHEST:
		chests.append(cell)
	for n in NEIGHBORS:
		var c := cell + n
		if chest_voxel >= 0 and world.get_voxel(c) == chest_voxel:
			world.set_voxel(c, IVoxelWorld.AIR)
			chests.append(c)
	if chests.is_empty():
		pity_chest += 1
		if pity_chest >= chest_pity_limit:
			chests.append(cell)
			pity_chest = 0
	else:
		pity_chest = 0
	return {"extra_geode": extra_geode, "chest_cells": chests}


## Draws a chest reward. Unlock kinds never repeat; exhausted pools fall back to coins.
## Returns {"kind": StringName, "id": StringName, "coins": int, "item": StringName, "qty": int}.
static func open_chest(table: TreasureTableDef, unlocks: UnlockModel, rng: RngStreams) -> Dictionary:
	var entries: Array = table.entries.duplicate()
	while not entries.is_empty():
		var weights := entries.map(func(e): return int(e.get("weight", 1)))
		var e: Dictionary = entries[rng.weighted_index("discovery", weights)]
		var kind := StringName(e.get("kind", "COINS"))
		match kind:
			&"COINS":
				return {"kind": kind, "id": &"", "coins": rng.randi_range("discovery", int(e["coins_min"]), int(e["coins_max"])), "item": &"", "qty": 0}
			&"ITEM":
				return {"kind": kind, "id": &"", "coins": 0, "item": StringName(e["item"]), "qty": int(e.get("qty", 1))}
			_:
				var remaining: Array = (e.get("id_pool", []) as Array).filter(func(i): return not unlocks.is_unlocked(kind, StringName(i)))
				if not remaining.is_empty():
					var pick := StringName(remaining[rng.randi_range("discovery", 0, remaining.size() - 1)])
					return {"kind": kind, "id": pick, "coins": 0, "item": &"", "qty": 0}
				entries.erase(e)   # pool exhausted: redraw among the rest
	return {"kind": &"COINS", "id": &"", "coins": rng.randi_range("discovery", table.fallback_coins_min, table.fallback_coins_max), "item": &"", "qty": 0}


func to_dict() -> Dictionary:
	return {"pity": {"geode": pity_geode, "chest": pity_chest}}


func from_dict(d: Dictionary) -> void:
	var p: Dictionary = d.get("pity", {})
	pity_geode = int(p.get("geode", 0))
	pity_chest = int(p.get("chest", 0))
