## A house assembled from Quaternius Medieval Village modules (spec 12.8): 2 m wall modules,
## 3 m storeys, a gable roof (or a tower roof) sized to the footprint. The footprint is centred
## on the node, the front (door) faces +Z. `layout()` is pure so it can be tested without art.
class_name VillageHouse
extends Node3D

const DIR := "res://assets/third_party/quaternius/village/"
const MODULE := 2.0
const STOREY := 3.0
## Gable roofs by footprint in metres (width x depth); the kit has no other sizes.
const ROOFS := {
	Vector2i(4, 4): "Roof_RoundTiles_4x4", Vector2i(4, 6): "Roof_RoundTiles_4x6",
	Vector2i(6, 4): "Roof_RoundTiles_6x4", Vector2i(6, 6): "Roof_RoundTiles_6x6",
	Vector2i(6, 8): "Roof_RoundTiles_6x8", Vector2i(8, 8): "Roof_RoundTiles_8x8",
}
const GABLES := {4: "Roof_Front_Brick4", 6: "Roof_Front_Brick6", 8: "Roof_Front_Brick8"}
const WALLS := {
	"plaster": {"wall": "Wall_Plaster_Straight", "door_round": "Wall_Plaster_Door_Round", "door_flat": "Wall_Plaster_Door_Flat",
		"wide": "Wall_Plaster_Window_Wide_Round", "thin": "Wall_Plaster_Window_Thin_Round", "accent": "Wall_Plaster_WoodGrid"},
	"brick": {"wall": "Wall_UnevenBrick_Straight", "door_round": "Wall_UnevenBrick_Door_Round", "door_flat": "Wall_UnevenBrick_Door_Round",
		"wide": "Wall_UnevenBrick_Window_Wide_Round", "thin": "Wall_UnevenBrick_Window_Thin_Round", "accent": "Wall_UnevenBrick_Straight"},
}
## The door model's hinge sits 0.51 m left of the opening centre, 0.1 m inside the wall face.
const DOOR_OFFSET := Vector3(-0.51, 0, -0.1)

@export_range(2, 4) var width := 2         # modules along x
@export_range(2, 4) var depth := 2         # modules along z
@export_range(1, 3) var storeys := 1
## Wall style per storey ("plaster" or "brick"); the last entry repeats upward.
@export var styles: PackedStringArray = PackedStringArray(["plaster"])
## Front module holding the door (-1 = middle, rounded down).
@export var door_module := -1
@export var round_door := true
@export var windows := true
@export var chimney := true
## "gable" or "tower" (tower: 2 x 2 modules only).
@export var roof := "gable"


func config() -> Dictionary:
	return {"width": width, "depth": depth, "storeys": storeys, "styles": styles, "door_module": door_module,
		"round_door": round_door, "windows": windows, "chimney": chimney, "roof": roof}


func _ready() -> void:
	for e: Dictionary in layout(config()):
		var ps := load(DIR + String(e["piece"]) + ".gltf") as PackedScene
		if ps == null:
			push_error("VillageHouse: missing piece %s" % e["piece"])
			continue
		var n: Node3D = ps.instantiate()
		n.position = e["pos"]
		n.rotation_degrees.y = float(e["yaw"])
		if e.get("centre", false):
			# kit roofs have inconsistent pivots: centre them on the footprint by their bounds
			var b := ModelFit.local_aabb(n)
			n.position.x -= b.get_center().x
			n.position.z -= b.get_center().z
		add_child(n)


## Local box of the walls (no roof overhang): the house collider (spec 12.8).
func collision_box() -> AABB:
	return box_for(config())


## Local point 0.6 m in front of the door, on the ground.
func door_point() -> Vector3:
	return door_point_for(config())


static func box_for(cfg: Dictionary) -> AABB:
	var w := float(cfg["width"]) * MODULE
	var d := float(cfg["depth"]) * MODULE
	return AABB(Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w, float(cfg["storeys"]) * STOREY, d))


static func door_point_for(cfg: Dictionary) -> Vector3:
	return Vector3(_door_x(cfg), 0, float(cfg["depth"]) * MODULE * 0.5 + 0.6)


static func _door_index(cfg: Dictionary) -> int:
	var i := int(cfg.get("door_module", -1))
	return int(cfg["width"]) / 2 if i < 0 else clampi(i, 0, int(cfg["width"]) - 1)


static func _door_x(cfg: Dictionary) -> float:
	return -float(cfg["width"]) * MODULE * 0.5 + MODULE * 0.5 + MODULE * _door_index(cfg)


## Pieces as {"piece": file base name, "pos": Vector3, "yaw": degrees, "centre": bool}.
static func layout(cfg: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wm := int(cfg["width"])
	var dm := int(cfg["depth"])
	var hw := wm * MODULE * 0.5
	var hd := dm * MODULE * 0.5
	var st := int(cfg["storeys"])
	var styles: PackedStringArray = cfg.get("styles", PackedStringArray(["plaster"]))
	var door := _door_index(cfg)
	var win: bool = cfg.get("windows", true)
	for s in st:
		var y := s * STOREY
		var set: Dictionary = WALLS[styles[mini(s, styles.size() - 1)] if styles.size() > 0 else "plaster"]
		# floor of this storey
		for ix in wm:
			for iz in dm:
				out.append({"piece": "Floor_WoodDark", "pos": Vector3(-hw + 1 + 2 * ix, y + 0.01, -hd + 1 + 2 * iz), "yaw": 0})
		# front (+Z) and back (-Z)
		for ix in wm:
			var x := -hw + 1 + 2 * ix
			var front: String = set["wall"]
			if s == 0 and ix == door:
				front = set["door_round"] if cfg.get("round_door", true) else set["door_flat"]
				var dp := Vector3(x, y, hd) + DOOR_OFFSET
				out.append({"piece": "Door_1_Round" if cfg.get("round_door", true) else "Door_1_Flat", "pos": dp, "yaw": 0})
			elif win:
				front = set["wide"]
				_window(out, Vector3(x, y, hd), 0, true)
			out.append({"piece": front, "pos": Vector3(x, y, hd), "yaw": 0})
			var back: String = set["thin"] if win and (ix + s) % 2 == 0 else set["accent"]
			if back == set["thin"]:
				_window(out, Vector3(x, y, -hd), 180, false)
			out.append({"piece": back, "pos": Vector3(x, y, -hd), "yaw": 180})
		# left (-X) and right (+X)
		for iz in dm:
			var z := -hd + 1 + 2 * iz
			for side in [-1, 1]:
				var yaw := -90 if side < 0 else 90
				var with_win := win and (iz + s + (1 if side > 0 else 0)) % 2 == 0
				if with_win:
					_window(out, Vector3(side * hw, y, z), yaw, false)
				out.append({"piece": set["thin"] if with_win else set["wall"], "pos": Vector3(side * hw, y, z), "yaw": yaw})
		for c in [Vector3(-hw, y, -hd), Vector3(hw, y, -hd), Vector3(-hw, y, hd), Vector3(hw, y, hd)]:
			out.append({"piece": "Corner_Exterior_Wood", "pos": c, "yaw": 0})
	var top := st * STOREY
	if String(cfg.get("roof", "gable")) == "tower":
		out.append({"piece": "Roof_Tower_RoundTiles", "pos": Vector3(0, top, 0), "yaw": 0, "centre": true})
	else:
		var key := Vector2i(int(wm * MODULE), int(dm * MODULE))
		if ROOFS.has(key):
			out.append({"piece": ROOFS[key], "pos": Vector3(0, top, 0), "yaw": 0, "centre": true})
			out.append({"piece": GABLES[key.x], "pos": Vector3(0, top, hd), "yaw": 0})
			out.append({"piece": GABLES[key.x], "pos": Vector3(0, top, -hd), "yaw": 180})
	if cfg.get("chimney", false):
		out.append({"piece": "Prop_Chimney", "pos": Vector3(hw * 0.5, top, -hd * 0.5), "yaw": 0})
	return out


static func _window(out: Array[Dictionary], pos: Vector3, yaw: int, wide: bool) -> void:
	out.append({"piece": "Window_Wide_Round1" if wide else "Window_Thin_Round1", "pos": pos, "yaw": yaw})
	out.append({"piece": "WindowShutters_Wide_Round_Open" if wide else "WindowShutters_Thin_Round_Open", "pos": pos, "yaw": yaw})
