## Magnetic snapping (spec 2.7, plan P3.4). Pure.
## Sockets: [{"position": Vector3, "provides": StringName, "cell": Vector3i, "rot": int, "key": String}]
## (placed pieces' world sockets plus `ground` sockets for aimed voxel top faces).
## Result: {"snapped": bool, "cell": Vector3i, "rot": int, "position": Vector3, "key": String}.
class_name SnapAssistModel
extends RefCounted

const STRUCTURE_RADIUS := [0.30, 0.45, 0.60]   # Low, Normal, High
const FURNITURE_RADIUS := [0.20, 0.30, 0.35]
const STICKY_FACTOR := 1.5

var strength := 2   # High (default, spec 5.10)
var sticky_key := ""


static func radius(strength_index: int, furniture: bool) -> float:
	var t: Array = FURNITURE_RADIUS if furniture else STRUCTURE_RADIUS
	return t[clampi(strength_index, 0, 2)]


func reset() -> void:
	sticky_key = ""


func resolve(def: BuildPieceDef, raw_point: Vector3, sockets: Array, manual_rot: int) -> Dictionary:
	var rad := radius(strength, def.is_furniture())
	var compatible := sockets.filter(func(s): return s["provides"] in def.accepts)
	# Sticky: keep the current socket until the raw point leaves 1.5x radius.
	if sticky_key != "":
		for s in compatible:
			if s["key"] == sticky_key and raw_point.distance_to(s["position"]) <= rad * STICKY_FACTOR:
				return _snap(s)
		sticky_key = ""
	var best: Dictionary = {}
	var best_d := INF
	for s in compatible:
		var d := raw_point.distance_to(s["position"])
		if d > rad:
			continue
		if d < best_d - 0.000001 or (absf(d - best_d) <= 0.000001 and String(s["key"]) < String(best["key"])):
			best = s
			best_d = d
	if not best.is_empty():
		sticky_key = best["key"]
		return _snap(best)
	var cell := BuildGrid.cell_of_point(raw_point)
	return {"snapped": false, "cell": cell, "rot": posmod(manual_rot, 4), "position": Vector3(cell) + Vector3(0.5, 0, 0.5), "key": ""}


func _snap(s: Dictionary) -> Dictionary:
	return {"snapped": true, "cell": s["cell"], "rot": s["rot"], "position": s["position"], "key": s["key"]}
