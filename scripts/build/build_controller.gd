## Build mode driver (spec 2.3 Build, 2.7, 4.4; plan P3.7). Child of the player. The Build
## state calls tick() on the ground; the player calls it while airborne for single-shot
## placement (pillar building). Rules live in BuildModel, SnapAssistModel, FastenModel,
## PlacementValidator and BuildService.
class_name BuildController
extends Node

const REACH := 4.5
const STRENGTHS := {"low": 0, "normal": 1, "high": 2}

var player: PlayerController
var model := BuildModel.new()
var snap := SnapAssistModel.new()
var fasten := FastenModel.new()
var fasten_uid := ""
var ghost: GhostView
var aim: Dictionary = {}
var preview: Dictionary = {}
var _last_ghost := ""


func setup(p: PlayerController) -> void:
	player = p
	ghost = GhostView.new()
	ghost.name = "Ghost"
	add_child(ghost)


func session() -> GameSession:
	return GameSession.current


func enter() -> void:
	model.reset()
	snap.reset()
	fasten_uid = ""
	if model.selected.is_empty() or not _has_selected():
		model.selected = default_selection()
	EventBus.build_mode_changed.emit(true)


func exit() -> void:
	model.end_fasten()
	fasten_uid = ""
	preview = {}
	ghost.hide_all()
	EventBus.build_mode_changed.emit(false)


func is_fastening() -> bool:
	return model.sub == BuildModel.FASTEN


func default_selection() -> Dictionary:
	var s := session()
	if s == null:
		return {}
	for def in Database.pieces.values():
		if s.inventory.count(def.item_id) > 0:
			return {"kind": &"piece", "id": def.id}
	for it in Database.items.values():
		if it.category == &"BLOCK" and s.inventory.count(it.id) > 0:
			return {"kind": &"block", "id": it.block_material}
	return {}


func _has_selected() -> bool:
	return selected_item() != &"" and session().inventory.count(selected_item()) > 0


func selected_item() -> StringName:
	if model.selected.is_empty():
		return &""
	if model.selected["kind"] == &"piece":
		var d: BuildPieceDef = Database.pieces.get(model.selected["id"])
		return d.item_id if d else &""
	return session().build.block_item_of(model.selected["id"])


func _apply_settings() -> void:
	snap.strength = STRENGTHS.get(String(Settings.get_value("assist", "snap_strength")), 2)
	model.remove_hold = float(Settings.get_value("assist", "remove_hold_sec"))


func tick(delta: float, f: InputFrame, airborne: bool) -> void:
	var s := session()
	if s == null:
		return
	_apply_settings()
	if not airborne and model.sub != BuildModel.FASTEN:
		if f.build_tool_next_pressed:
			model.next_tool()
		elif f.build_tool_prev_pressed:
			model.prev_tool()
		if f.rotate_cw_pressed:
			model.rotate(-1)
			snap.reset()
		elif f.rotate_ccw_pressed:
			model.rotate(1)
			snap.reset()
		if f.catalog_pressed:
			open_catalog()
			return
		if f.interact_pressed:
			pick()
	_update_aim(s)
	if model.tool != BuildModel.PLACE:
		preview = {}
		_show()
		return
	if model.sub == BuildModel.FASTEN:
		if f.duck_pressed or f.alt_pressed:
			model.end_fasten()
		else:
			_fasten_input(f, delta)
		_show()
		return
	_update_preview(s)
	if not airborne:
		_update_fasten_target(s)
		var target := remove_target(s)
		if model.tick_remove(delta, f.alt_held, not target.is_empty()):
			_remove(s, target)
			_show()
			return
	if f.use_pressed and model.sub == BuildModel.PREVIEW:
		if not airborne and fasten_uid != "" and fasten.current >= 0 and _fasten_tool_ok(s):
			model.begin_fasten()
			_fasten_input(f, delta)
		else:
			place()
	_show()


func _show() -> void:
	if preview.is_empty():
		ghost.hide_all()
	else:
		ghost.show_preview(preview, StringName(Settings.get_value("accessibility", "color_palette")))
	ghost.show_reticle(fasten.positions[fasten.current] if fasten_uid != "" and fasten.current >= 0 else null)
	var sig := "%s:%s" % [ghost.state, ghost.reason]
	if sig != _last_ghost:
		_last_ghost = sig
		EventBus.ghost_changed.emit(ghost.state, ghost.reason)


func _ray() -> Array:
	return player.tool_selector._ray()


## Nearest of the aimed piece (physics, build_pieces layer) and the aimed voxel.
func _update_aim(s: GameSession) -> void:
	aim = {}
	var ray := _ray()
	if ray.is_empty():
		return
	var origin: Vector3 = ray[0]
	var dir: Vector3 = (ray[1] as Vector3).normalized()
	aim = {"origin": origin, "dir": dir}
	var best := INF
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * REACH, PieceView.LAYER)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit["collider"].has_meta(&"uid"):
		best = origin.distance_to(hit["position"])
		aim["piece_uid"] = String(hit["collider"].get_meta(&"uid"))
		aim["point"] = hit["position"]
		aim["normal"] = hit["normal"]
	var vh := s.terrain.world.raycast(origin, dir, REACH)
	if not vh.is_empty() and float(vh["distance"]) < best:
		aim.erase("piece_uid")
		aim["voxel_cell"] = vh["cell"]
		aim["prev_cell"] = vh["prev_cell"]
		aim["point"] = origin + dir * float(vh["distance"])
		aim["normal"] = Vector3(vh["prev_cell"] - vh["cell"])


func _update_preview(s: GameSession) -> void:
	preview = {}
	if model.selected.is_empty() or not aim.has("point"):
		return
	var point: Vector3 = aim["point"]
	var adjacent := BuildGrid.cell_of_point(point + (aim["normal"] as Vector3) * 0.05)
	if aim.has("prev_cell"):
		adjacent = aim["prev_cell"]
	if model.selected["kind"] == &"block":
		var reason := s.terrain.rules.can_place(adjacent)
		if s.inventory.count(selected_item()) <= 0:
			reason = PlacementValidator.MISSING_ITEM
		elif player.global_position.distance_to(Vector3(adjacent) + Vector3(0.5, 0.5, 0.5)) > REACH:
			reason = &"outside_reach"
		preview = {"kind": &"block", "id": model.selected["id"], "cell": adjacent, "rot": 0, "cells": [adjacent],
			"valid": reason == &"", "reason": reason, "snapped": false}
		return
	var def: BuildPieceDef = Database.pieces.get(model.selected["id"])
	var sockets := _sockets_near(s, point, def)
	var r := snap.resolve(def, point, sockets, model.manual_rot)
	var cell: Vector3i = r["cell"] if r["snapped"] else adjacent
	var v := s.build.validate(def.id, cell, r["rot"])
	preview = {"kind": &"piece", "id": def.id, "cell": cell, "rot": r["rot"], "cells": v["cells"],
		"valid": v["ok"], "reason": v["reason"], "snapped": r["snapped"]}


func _sockets_near(s: GameSession, point: Vector3, def: BuildPieceDef) -> Array:
	var out: Array = []
	for inst in s.build.pieces_in(SceneRouter.current_zone_id):
		if Vector3(inst["cell"]).distance_to(point) > 4.0:
			continue
		var d: BuildPieceDef = Database.pieces[StringName(inst["piece_id"])]
		out.append_array(BuildGrid.world_sockets(d, inst["cell"], inst["rot"], inst["uid"]))
	if aim.has("voxel_cell") and aim["prev_cell"] == aim["voxel_cell"] + Vector3i.UP:
		var top: Vector3i = aim["voxel_cell"]
		out.append({"position": Vector3(top) + Vector3(0.5, 1.0, 0.5), "provides": &"ground",
			"cell": aim["prev_cell"], "rot": model.manual_rot, "key": "ground:%d,%d,%d" % [top.x, top.y, top.z]})
	return out


func place() -> bool:
	var s := session()
	if preview.is_empty() or not preview["valid"]:
		return false
	var r: Result
	if preview["kind"] == &"piece":
		r = s.build.try_place(preview["id"], preview["cell"], preview["rot"])
	else:
		r = s.build.try_place_block(preview["cell"], preview["id"])
	if r.ok:
		snap.reset()
		if not _has_selected():
			var keep: Dictionary = model.selected
			model.selected = default_selection()
			if model.selected.is_empty():
				model.selected = keep
	return r.ok


## X: pick the piece or block type under aim (spec 2.3).
func pick() -> void:
	var s := session()
	if aim.has("piece_uid") and s.build.pieces.has(aim["piece_uid"]):
		model.selected = {"kind": &"piece", "id": StringName(s.build.pieces[aim["piece_uid"]]["piece_id"])}
	elif aim.has("voxel_cell"):
		var mat := s.terrain.material_at(aim["voxel_cell"])
		if mat and mat.placeable:
			model.selected = {"kind": &"block", "id": mat.id}


func open_catalog() -> void:
	if MenuStack.instance == null:
		return
	model.open_catalog()
	MenuStack.instance.push(&"build_catalog", {"on_close": func(res): model.close_catalog(res if res is Dictionary else {})})


func remove_target(s: GameSession) -> Dictionary:
	if aim.has("piece_uid"):
		var inst: Dictionary = s.build.pieces.get(aim["piece_uid"], {})
		if not inst.is_empty() and s.housing.plot_at(StringName(inst["zone"]), inst["cell"]) != null:
			return {"uid": aim["piece_uid"]}
	elif aim.has("voxel_cell"):
		var c: Vector3i = aim["voxel_cell"]
		var mat := s.terrain.material_at(c)
		if mat and mat.placeable and s.housing.plot_at(SceneRouter.current_zone_id, c) != null:
			return {"cell": c}
	return {}


func _remove(s: GameSession, target: Dictionary) -> void:
	if target.has("uid"):
		s.build.try_remove(target["uid"])
	else:
		s.build.try_remove_block(target["cell"])


func _fasten_tool_ok(s: GameSession) -> bool:
	var def := s.build.def_of(fasten_uid)
	if def == null:
		return false
	var need := ToolTypes.HAMMER if def.fastener == BuildPieceDef.NAILS else ToolTypes.SCREWDRIVER
	if s.toolbelt.model.equipped != need:
		player.tool_selector.commit_now()
	return s.toolbelt.model.equipped == need


func _update_fasten_target(s: GameSession) -> void:
	var uid: String = aim.get("piece_uid", "")
	var inst: Dictionary = s.build.pieces.get(uid, {})
	if inst.is_empty() or inst["state"] != BuildService.LOOSE:
		fasten_uid = ""
		return
	if uid != fasten_uid:
		var def := s.build.def_of(uid)
		var pos: Array[Vector3] = []
		for p in def.fastener_sockets:
			pos.append(BuildGrid.world_point(inst["cell"], inst["rot"], p))
		fasten.setup(pos, def.fastener, def.hits_per_socket, String(Settings.get_value("assist", "fasten_mode")) == "hold", inst["fasten"])
		fasten_uid = uid
	fasten.aim(aim["origin"], aim["dir"], FastenModel.ANGLES[snap.strength])


func _fasten_input(f: InputFrame, delta: float) -> void:
	var s := session()
	var idx := fasten.current
	if idx < 0:
		model.end_fasten()
		return
	var ev := fasten.hold(delta) if fasten.uses_hold() and f.use_held else (fasten.press() if f.use_pressed else FastenModel.NONE)
	if ev == FastenModel.NONE:
		return
	var r := s.build.fasten_step(fasten_uid, idx)
	if not r.ok:
		fasten.hits[idx] -= 1   # refused (no stamina): undo the local hit
		model.end_fasten()
		return
	if ev == FastenModel.DONE:
		model.end_fasten()
		fasten_uid = ""


## Reticle state for tests and the HUD.
func reticle_socket() -> int:
	return fasten.current if fasten_uid != "" else -1
