## Stamps (spec 7.2). Pure. Stamps live in the piece's local space:
## {"sticker_id", "pos": [x, y, z], "normal": [x, y, z], "rot_deg": int (45 steps), "size": "S"|"M"|"L"}.
class_name StampModel
extends RefCounted

const CAP := 8
const SIZES := {"S": 0.25, "M": 0.5, "L": 1.0}
const FULL := &"stamp_cap"
const NOT_STAMPABLE := &"not_stampable"
const LOCKED := &"sticker_locked"
const NONE := &"no_stamp"


static func check(def: BuildPieceDef, stamps: Array, owned: bool, unlocked: bool) -> StringName:
	if not owned:
		return PaintModel.NOT_OWNED
	if not def.stampable:
		return NOT_STAMPABLE
	if not unlocked:
		return LOCKED
	if stamps.size() >= CAP:
		return FULL
	return &""


static func make(sticker_id: StringName, local_pos: Vector3, local_normal: Vector3, rot_deg: int, size: String) -> Dictionary:
	return {"sticker_id": String(sticker_id), "pos": [snappedf(local_pos.x, 0.001), snappedf(local_pos.y, 0.001), snappedf(local_pos.z, 0.001)],
		"normal": [snappedf(local_normal.x, 0.001), snappedf(local_normal.y, 0.001), snappedf(local_normal.z, 0.001)],
		"rot_deg": posmod(int(round(rot_deg / 45.0)) * 45, 360), "size": size if SIZES.has(size) else "M"}


## Index of the stamp nearest `local_point` within `max_dist`, or -1.
static func nearest(stamps: Array, local_point: Vector3, max_dist: float = 0.75) -> int:
	var best := -1
	var best_d := max_dist
	for i in stamps.size():
		var p: Array = stamps[i]["pos"]
		var d := local_point.distance_to(Vector3(p[0], p[1], p[2]))
		if d <= best_d:
			best = i
			best_d = d
	return best


static func to_local(world_point: Vector3, cell: Vector3i, rot: int) -> Vector3:
	var p := world_point - Vector3(cell) - Vector3(0.5, 0, 0.5)
	return p.rotated(Vector3.UP, -rot * PI / 2.0)


static func to_world(local: Vector3, cell: Vector3i, rot: int) -> Vector3:
	return Vector3(cell) + Vector3(0.5, 0, 0.5) + local.rotated(Vector3.UP, rot * PI / 2.0)
