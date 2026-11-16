## Build pieces, fastening, furniture state and block placement (spec 1.8, 2.7, 4.4, D17).
## Occupancy is shared with TerrainRules through its building_supported / piece_occupied
## hooks (9.3 P4), re-bound whenever a zone loads.
class_name BuildService
extends Node

const LOOSE := &"LOOSE"
const FASTENED := &"FASTENED"
const NOT_OWN := &"not_own_piece"
const HAS_DEPENDENTS := &"has_dependents"
const UNKNOWN := &"unknown_piece"
const NOT_PLACEABLE := &"not_placeable"
const OUTSIDE_PLOT := &"outside_plot"

var session: GameSession
var pieces: Dictionary = {}        # uid -> {"uid", "piece_id", "zone", "cell", "rot", "state", "fasten", "toggle"}
var occupancy: Dictionary = {}     # zone -> {key -> uid}
var placed_blocks: Dictionary = {} # "zone/x,y,z" -> material id (blocks placed inside owned plots)
var next_uid := 1


func setup(s: GameSession) -> void:
	session = s


func zone() -> StringName:
	return SceneRouter.current_zone_id


func _z(z: StringName) -> StringName:
	return z if z != &"" else zone()


func def_of(uid: String) -> BuildPieceDef:
	return Database.pieces.get(StringName(pieces[uid]["piece_id"])) if pieces.has(uid) else null


func occ(z: StringName) -> Dictionary:
	if not occupancy.has(z):
		occupancy[z] = {}
	return occupancy[z]


func context(z: StringName = &"", piece_item: StringName = &"") -> PlacementValidator.PlacementContext:
	z = _z(z)
	var ctx := PlacementValidator.PlacementContext.new()
	ctx.world = session.terrain.world
	ctx.zone = z
	ctx.occupancy = occ(z)
	ctx.pieces = pieces
	ctx.plots = session.housing.owned_plot_defs(z)
	ctx.player_cells = session.terrain.rules.player_cells
	ctx.pet_cells = session.terrain.rules.pet_cells
	ctx.has_item = piece_item == &"" or session.inventory.count(piece_item) > 0
	var rules := session.terrain.rules
	ctx.protected = func(c: Vector3i) -> bool: return rules.is_protected(c, true)
	return ctx


func validate(piece_id: StringName, cell: Vector3i, rot: int, z: StringName = &"") -> Dictionary:
	var def: BuildPieceDef = Database.pieces.get(piece_id)
	if def == null:
		return {"ok": false, "reason": UNKNOWN, "cells": [], "nudge_pet": false}
	return PlacementValidator.validate(context(z, def.item_id), def, cell, rot)


func try_place(piece_id: StringName, cell: Vector3i, rot: int, z: StringName = &"") -> Result:
	z = _z(z)
	var v := validate(piece_id, cell, rot, z)
	if not v["ok"]:
		return Result.failure(v["reason"])
	var def: BuildPieceDef = Database.pieces[piece_id]
	session.inventory.remove(def.item_id, 1)
	var uid := "p%04d" % next_uid
	next_uid += 1
	pieces[uid] = {"uid": uid, "piece_id": String(piece_id), "zone": String(z), "cell": cell, "rot": posmod(rot, 4),
		"state": LOOSE if def.needs_fastening() else FASTENED, "fasten": [], "toggle": 0}
	for o in BuildGrid.occupancy(def, cell, rot):
		occ(z)[o["key"]] = uid
	if v["nudge_pet"]:
		EventBus.pet_nudge_requested.emit(v["cells"])
	EventBus.piece_placed.emit(uid, piece_id, cell)
	EventBus.build_changed.emit(z)
	return Result.success(uid)


## One fastening step on `socket` (spec 2.7): a nail hit or a completed screw.
## Stamina: hammer hit 1, screw complete 1 (spec 6.1). Returns data {"done": bool}.
func fasten_step(uid: String, socket: int) -> Result:
	var inst: Dictionary = pieces.get(uid, {})
	if inst.is_empty():
		return Result.failure(UNKNOWN)
	var def := def_of(uid)
	if inst["state"] == FASTENED or not def.needs_fastening():
		return Result.failure(&"already_fastened")
	if not session.stamina.can_act():
		return Result.failure(&"no_stamina")
	var hits: Array = inst["fasten"]
	while hits.size() < def.fastener_sockets.size():
		hits.append(0)
	var need := 1 if def.fastener == BuildPieceDef.SCREWS else def.hits_per_socket
	if socket < 0 or socket >= hits.size() or hits[socket] >= need:
		return Result.failure(&"socket_done")
	hits[socket] += 1
	session.stamina.spend(1, &"fasten")
	var done := 0
	for h in hits:
		done += mini(h, need)
	var total := need * hits.size()
	EventBus.fasten_progressed.emit(uid, done, total)
	if done >= total:
		inst["state"] = FASTENED
		EventBus.piece_fastened.emit(uid)
		EventBus.build_changed.emit(StringName(inst["zone"]))
	return Result.success({"done": done >= total})


## Pieces resting on `uid`: anything in or on the cells directly above its footprint, and
## for floors, anything else in the same cells.
func dependents(uid: String) -> Array:
	var inst: Dictionary = pieces[uid]
	var def := def_of(uid)
	var o := occ(StringName(inst["zone"]))
	var out := {}
	for c in BuildGrid.cells(def, inst["cell"], inst["rot"]):
		var keys: Array[String] = BuildGrid.keys_touching(c + Vector3i.UP)
		if def.layer == BuildPieceDef.LAYER_FLOOR:
			keys.append_array(BuildGrid.keys_touching(c))
		for k in keys:
			if o.has(k) and o[k] != uid:
				out[o[k]] = true
	return out.keys()


func try_remove(uid: String) -> Result:
	if not pieces.has(uid):
		return Result.failure(UNKNOWN)
	var inst: Dictionary = pieces[uid]
	if session.housing.plot_at(StringName(inst["zone"]), inst["cell"]) == null:
		return Result.failure(NOT_OWN)
	if not dependents(uid).is_empty():
		return Result.failure(HAS_DEPENDENTS)
	if session.storage.has_items(uid):
		return Result.failure(&"not_empty")
	var def := def_of(uid)
	var z := StringName(inst["zone"])
	for o in BuildGrid.occupancy(def, inst["cell"], inst["rot"]):
		occ(z).erase(o["key"])
	pieces.erase(uid)
	session.world_state.give_drops([{"item": def.item_id, "qty": 1}], Vector3(inst["cell"]) + Vector3(0.5, 0.5, 0.5))
	EventBus.piece_removed.emit(uid, def.id)
	EventBus.build_changed.emit(z)
	return Result.success()


func toggle_furniture(uid: String) -> Result:
	var def := def_of(uid)
	if def == null:
		return Result.failure(UNKNOWN)
	var t := def.interaction(&"TOGGLE")
	if t.is_empty():
		return Result.failure(&"not_toggleable")
	pieces[uid]["toggle"] = (int(pieces[uid]["toggle"]) + 1) % maxi(2, int(t["toggle_states"]))
	EventBus.furniture_toggled.emit(uid, pieces[uid]["toggle"])
	return Result.success(pieces[uid]["toggle"])


func block_item_of(material_id: StringName) -> StringName:
	for it in Database.items.values():
		if it.category == &"BLOCK" and it.block_material == material_id:
			return it.id
	return &""


## Natural block placement (D17): TerrainRules.can_place (including piece occupancy), then
## one BLOCK item is consumed.
func try_place_block(cell: Vector3i, material_id: StringName, z: StringName = &"") -> Result:
	z = _z(z)
	var mat: VoxelMaterialDef = Database.materials.get(material_id)
	if mat == null or not mat.placeable:
		return Result.failure(NOT_PLACEABLE)
	var item := block_item_of(material_id)
	if item == &"" or session.inventory.count(item) <= 0:
		return Result.failure(PlacementValidator.MISSING_ITEM)
	var reason := session.terrain.rules.can_place(cell)
	if reason != TerrainRules.OK:
		return Result.failure(reason)
	session.inventory.remove(item, 1)
	session.terrain.world.set_voxel(cell, mat.voxel_id)
	if session.housing.plot_at(z, cell) != null:
		placed_blocks[FarmModel.key(z, cell)] = String(material_id)
	EventBus.block_placed.emit(cell, material_id)
	EventBus.voxel_placed.emit(cell, material_id)
	return Result.success()


## Instant removal inside owned plots (spec 4.4); elsewhere blocks are dug normally.
func try_remove_block(cell: Vector3i, z: StringName = &"") -> Result:
	z = _z(z)
	if session.housing.plot_at(z, cell) == null:
		return Result.failure(OUTSIDE_PLOT)
	var mat := session.terrain.material_at(cell)
	if mat == null or not mat.placeable:
		return Result.failure(NOT_PLACEABLE)
	var reason := session.terrain.can_dig(cell)
	if reason != TerrainRules.OK:
		return Result.failure(reason)
	session.terrain.world.set_voxel(cell, IVoxelWorld.AIR)
	placed_blocks.erase(FarmModel.key(z, cell))
	session.world_state.give_drops([{"item": block_item_of(mat.id), "qty": 1}], Vector3(cell) + Vector3(0.5, 0.5, 0.5))
	EventBus.block_removed.emit(cell, mat.id)
	return Result.success()


func pieces_in(z: StringName) -> Array:
	return pieces.values().filter(func(p): return StringName(p["zone"]) == z)


## Called by Zone._ready: P4 support and piece occupancy for this zone's TerrainRules, and
## the piece views.
func bind_zone(z: StringName, zone_node: Node3D) -> void:
	var rules := session.terrain.rules
	var o := occ(z)
	rules.building_supported = func(c: Vector3i) -> bool:
		for k in BuildGrid.keys_touching(c + Vector3i.UP):
			if o.has(k):
				return true
		return false
	rules.piece_occupied = func(c: Vector3i) -> bool:
		for k in BuildGrid.keys_touching(c):
			if o.has(k):
				return true
		return false
	var v := BuildView.new()
	v.name = "BuildView"
	v.zone_id = z
	zone_node.add_child(v)


## Debug command until Phase 4 sells plots (plan P3.2): deed for plot_test, hammer,
## screwdriver and a stack of pieces.
func grant_debug_kit() -> void:
	var kit: Dictionary = Database.build.get("debug_kit", {})
	session.housing.grant_deed(StringName(kit.get("plot", "plot_test")))
	for t in kit.get("tools", []):
		session.toolbelt.model.grant(StringName(t))
	for id in kit.get("items", {}):
		session.inventory.add(StringName(id), int(kit["items"][id]))


func to_dict() -> Dictionary:
	var out := {}
	for uid in pieces:
		var p: Dictionary = pieces[uid]
		var c: Vector3i = p["cell"]
		out[uid] = {"piece_id": p["piece_id"], "zone": p["zone"], "cell": [c.x, c.y, c.z], "rot": p["rot"],
			"state": String(p["state"]), "fasten": p["fasten"].duplicate(), "toggle": p["toggle"]}
	return {"pieces": out, "next_uid": next_uid, "placed_blocks": placed_blocks.duplicate()}


func from_dict(d: Dictionary) -> void:
	pieces.clear()
	occupancy.clear()
	placed_blocks.clear()
	next_uid = int(d.get("next_uid", 1))
	for uid in d.get("pieces", {}):
		var p: Dictionary = d["pieces"][uid]
		var def: BuildPieceDef = Database.pieces.get(StringName(p["piece_id"]))
		if def == null:
			push_warning("BuildService: dropping unknown piece %s" % p["piece_id"])
			continue
		var c: Array = p["cell"]
		var inst := {"uid": String(uid), "piece_id": String(p["piece_id"]), "zone": String(p["zone"]),
			"cell": Vector3i(int(c[0]), int(c[1]), int(c[2])), "rot": int(p["rot"]), "state": StringName(p["state"]),
			"fasten": (p.get("fasten", []) as Array).map(func(v): return int(v)), "toggle": int(p.get("toggle", 0))}
		pieces[String(uid)] = inst
		for o in BuildGrid.occupancy(def, inst["cell"], inst["rot"]):
			occ(StringName(inst["zone"]))[o["key"]] = String(uid)
	for k in d.get("placed_blocks", {}):
		placed_blocks[String(k)] = String(d["placed_blocks"][k])
