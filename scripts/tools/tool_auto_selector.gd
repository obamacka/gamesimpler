## Feeds ToolSelectionModel from the world each physics tick and applies its events (spec 2.6).
class_name ToolAutoSelector
extends Node

const REACH_FROM_CAMERA := 4.5
const REACH_FROM_PLAYER := 3.0

var player: Node3D
var detector: Area3D
var model: ToolSelectionModel
var _belt_bound: ToolBeltModel
var _tracked: Dictionary = {}       # key -> ToolTargetZone
var _aim_override: Array = []       # [origin, direction] for tests
var last_aim: Dictionary = {}


func setup(p: Node3D, det: Area3D) -> void:
	player = p
	detector = det


func set_aim_for_tests(origin: Vector3, direction: Vector3) -> void:
	_aim_override = [origin, direction]


func clear_aim_override() -> void:
	_aim_override = []


func _bind(session: GameSession) -> void:
	if _belt_bound != session.toolbelt.model:
		_belt_bound = session.toolbelt.model
		model = ToolSelectionModel.new(_belt_bound)
		_tracked.clear()


func tick(delta: float, locked: bool) -> void:
	var session := GameSession.current
	if session == null:
		return
	_bind(session)
	model.enabled = bool(Settings.get_value("assist", "auto_tool"))
	model.revert_when_idle = bool(Settings.get_value("assist", "auto_tool_revert"))
	last_aim = aim_target(session)
	var events := model.update(delta, last_aim, zone_candidates(), locked)
	apply(events)


func apply(events: Array) -> void:
	var session := GameSession.current
	for e in events:
		match e["type"]:
			&"equip":
				EventBus.tool_equipped.emit(e["tool"], session.toolbelt.model.owned.get(e["tool"], &""), &"manual" if e["reason"] == &"manual" else &"auto")
				if e["reason"] != &"manual":
					EventBus.tool_auto_selected.emit(e["tool"], e["target_kind"], e["reason"])
			&"unequip":
				EventBus.tool_unequipped.emit(&"auto")
			&"prompt":
				EventBus.prompt_changed.emit(e["key"], e["state"], e["tool"])


## Wheel Tools page (spec 2.6 rule 6). Phase 5's wheel calls this.
func manual_select(tool: StringName) -> bool:
	if model == null:
		return false
	var e := model.manual_select(tool)
	if e.is_empty():
		return false
	apply([e])
	return true


func commit_now() -> void:
	if model:
		var e := model.commit_now()
		if not e.is_empty():
			apply([e])


func best() -> Dictionary:
	return model.last_best if model else {}


func _ray() -> Array:
	if not _aim_override.is_empty():
		return _aim_override
	var cam := player.get_viewport().get_camera_3d()
	if cam == null:
		return []
	return [cam.global_position, -cam.global_transform.basis.z]


## Aimed voxel or aimed zone (whichever is nearer), as a ToolSelectionModel aim dictionary.
func aim_target(session: GameSession) -> Dictionary:
	var ray := _ray()
	if ray.is_empty():
		return {}
	var origin: Vector3 = ray[0]
	var dir: Vector3 = (ray[1] as Vector3).normalized()
	var best_aim := {}
	var best_dist := INF
	var hit := session.terrain.world.raycast(origin, dir, REACH_FROM_CAMERA)
	if not hit.is_empty():
		var cell: Vector3i = hit["cell"]
		var center := Vector3(cell) + Vector3(0.5, 0.5, 0.5)
		if player.global_position.distance_to(center) <= REACH_FROM_PLAYER + 0.5:
			var mat := Database.material_by_voxel(hit["voxel_id"])
			var reason := session.terrain.can_dig(cell)
			if mat and reason != TerrainRules.NOT_LOADED:
				best_dist = hit["distance"]
				best_aim = {"key": "voxel:%d,%d,%d" % [cell.x, cell.y, cell.z], "kind": &"voxel", "cell": cell,
					"tool": mat.preferred_tool, "target_kind": &"voxel_hard" if mat.is_hard() else &"voxel_soft",
					"tier_required": mat.hardness_tier if mat.is_hard() else 0,
					"blocked": reason if reason != TerrainRules.OK else &""}
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * REACH_FROM_CAMERA, ToolTargetZone.LAYER)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var zh := space.intersect_ray(q)
	if not zh.is_empty() and zh["collider"] is ToolTargetZone:
		var z: ToolTargetZone = zh["collider"]
		if z.is_active() and origin.distance_to(zh["position"]) < best_dist:
			best_aim = {"key": z.key, "kind": &"zone", "node": z, "tool": z.tool, "target_kind": z.target_kind, "tier_required": 0, "blocked": &""}
	return best_aim


func zone_candidates() -> Array:
	var out: Array = []
	var seen := {}
	var pos := player.global_position
	for a in detector.get_overlapping_areas():
		if a is ToolTargetZone:
			out.append(a.as_candidate(pos, true))
			seen[a.key] = true
			_tracked[a.key] = a
	for k in _tracked.keys():
		var z = _tracked[k]
		if not is_instance_valid(z):
			_tracked.erase(k)
			continue
		if not seen.has(k):
			var c: Dictionary = z.as_candidate(pos, false)
			if c["distance"] > c["enter_radius"] + ToolSelectionModel.ZONE_HYSTERESIS:
				_tracked.erase(k)
			out.append(c)
	return out
