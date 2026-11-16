## Build lattice helpers (spec 1.6). Pure and static.
## Rotation r (0..3) turns (x, z) into (z, -x) r times, which matches
## Basis(Vector3.UP, r * PI / 2) about the anchor cell's vertical center line.
class_name BuildGrid
extends RefCounted


static func rotate_offset(v: Vector3i, r: int) -> Vector3i:
	var o := v
	for i in posmod(r, 4):
		o = Vector3i(o.z, o.y, -o.x)
	return o


## Rotates a local point (meters from the anchor cell origin) about the cell center line.
static func rotate_point(p: Vector3, r: int) -> Vector3:
	var x := p.x - 0.5
	var z := p.z - 0.5
	for i in posmod(r, 4):
		var t := x
		x = z
		z = -t
	return Vector3(x + 0.5, p.y, z + 0.5)


static func world_point(anchor: Vector3i, r: int, local: Vector3) -> Vector3:
	return Vector3(anchor) + rotate_point(local, r)


static func cell_key(prefix: String, c: Vector3i) -> String:
	return "%s:%d,%d,%d" % [prefix, c.x, c.y, c.z]


## Canonical key of a cell face. Unrotated wall panels sit on the -z face; rotation r moves
## the face to -z (0), -x (1), +z (2), +x (3). Two walls on the same edge collide.
static func edge_key(c: Vector3i, r: int) -> String:
	match posmod(r, 4):
		0: return cell_key("ez", c)
		1: return cell_key("ex", c)
		2: return cell_key("ez", c + Vector3i(0, 0, 1))
		_: return cell_key("ex", c + Vector3i(1, 0, 0))


## Occupancy entries [{"cell", "key"}] for a piece at `anchor` with rotation `r`.
static func occupancy(def: BuildPieceDef, anchor: Vector3i, r: int) -> Array:
	var out: Array = []
	for f in def.footprint:
		var c := anchor + rotate_offset(f, r)
		var key: String
		match def.layer:
			BuildPieceDef.LAYER_FLOOR: key = cell_key("f", c)
			BuildPieceDef.LAYER_WALL: key = edge_key(c, r)
			_: key = cell_key("b", c)
		out.append({"cell": c, "key": key})
	return out


static func cells(def: BuildPieceDef, anchor: Vector3i, r: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for f in def.footprint:
		out.append(anchor + rotate_offset(f, r))
	return out


static func opening_cells(def: BuildPieceDef, anchor: Vector3i, r: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for f in def.opening:
		out.append(anchor + rotate_offset(f, r))
	return out


## Every occupancy key that lies in or on `c` (floor, body, its four faces).
static func keys_touching(c: Vector3i) -> Array[String]:
	return [cell_key("f", c), cell_key("b", c), cell_key("ez", c), cell_key("ez", c + Vector3i(0, 0, 1)),
		cell_key("ex", c), cell_key("ex", c + Vector3i(1, 0, 0))]


## World snap sockets of a placed piece: [{"position", "provides", "cell", "rot", "key"}].
static func world_sockets(def: BuildPieceDef, anchor: Vector3i, r: int, uid: String) -> Array:
	var out: Array = []
	for i in def.snap_sockets.size():
		var s: Dictionary = def.snap_sockets[i]
		out.append({"position": world_point(anchor, r, s["position"]), "provides": s["provides"],
			"cell": anchor + rotate_offset(s["attach_offset"], r), "rot": posmod(int(s["attach_rot"]) + r, 4),
			"key": "%s#%d" % [uid, i]})
	return out


static func cell_of_point(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x), floori(p.y), floori(p.z))
