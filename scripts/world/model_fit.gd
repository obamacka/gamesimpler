## Fits an imported model into a target box (spec 11.3): turn by yaw_deg about +Y, scale
## uniformly so the turned model fits inside the box, stand it on the box floor and centre it
## in x and z. Pure transform math over the model's mesh AABBs.
class_name ModelFit
extends RefCounted

## One world scale for furniture and station models (spec 11.4, 12.8): metres per model unit.
## The Quaternius kits are metric.
const WORLD_SCALE := 1.0
## Largest model overhang past its footprint per side (spec 11.4, 12.8).
const MAX_OVERHANG := 0.25


## Loads and instantiates a model scene; null if the path is empty or not a PackedScene.
static func instantiate(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	return ps.instantiate() as Node3D


## Every MeshInstance3D under root (root included).
static func mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(mesh_instances(c))
	return out


## AABB of all meshes in root's local space (root's own transform excluded).
static func local_aabb(root: Node3D) -> AABB:
	var acc := [null]
	_merge(root, Transform3D.IDENTITY, acc, true)
	return acc[0] if acc[0] != null else AABB()


static func _merge(n: Node, xf: Transform3D, acc: Array, is_root: bool) -> void:
	var t := xf
	if n is Node3D and not is_root:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var b: AABB = t * (n as MeshInstance3D).get_aabb()
		acc[0] = b if acc[0] == null else (acc[0] as AABB).merge(b)
	for c in n.get_children():
		_merge(c, t, acc, false)


## Sets model.transform (relative to its parent) so the model fits `box`, given in the
## parent's space. Returns the uniform scale used (0 if the model has no extent).
static func fit(model: Node3D, box: AABB, yaw_deg: int) -> float:
	var src := local_aabb(model)
	var basis := Basis(Vector3.UP, deg_to_rad(float(yaw_deg)))
	var turned: AABB = Transform3D(basis, Vector3.ZERO) * src
	var s := INF
	for axis in 3:
		if turned.size[axis] > 0.0001:
			s = minf(s, box.size[axis] / turned.size[axis])
	if s == INF:
		return 0.0
	var scaled := AABB(turned.position * s, turned.size * s)
	var target := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var have := Vector3(scaled.get_center().x, scaled.position.y, scaled.get_center().z)
	model.transform = Transform3D(basis.scaled(Vector3.ONE * s), target - have)
	return s


## Places a model at a fixed uniform scale (spec 11.4): turned by yaw_deg, centred in `box`
## in x and z, standing on the box floor. Returns the model's AABB in the parent's space.
static func place(model: Node3D, box: AABB, yaw_deg: int, scale: float = WORLD_SCALE) -> AABB:
	var src := local_aabb(model)
	var basis := Basis(Vector3.UP, deg_to_rad(float(yaw_deg)))
	var turned: AABB = Transform3D(basis, Vector3.ZERO) * src
	var scaled := AABB(turned.position * scale, turned.size * scale)
	var target := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var have := Vector3(scaled.get_center().x, scaled.position.y, scaled.get_center().z)
	model.transform = Transform3D(basis.scaled(Vector3.ONE * scale), target - have)
	return AABB(scaled.position + target - have, scaled.size)


## Seat height (spec 12.8): the highest vertex over the front 40% of the model's depth (+Z is
## the front), in the space `xf` maps the root into. 0 for a model without vertices.
static func seat_height(root: Node3D, xf: Transform3D) -> float:
	var verts: PackedVector3Array = []
	for mi in mesh_instances(root):
		var t := xf * _relative(root, mi)
		for s in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				verts.append(t * v)
	if verts.is_empty():
		return 0.0
	var z0 := INF
	var z1 := -INF
	for v in verts:
		z0 = minf(z0, v.z)
		z1 = maxf(z1, v.z)
	var top := -INF
	for v in verts:
		if (v.z - z0) / maxf(0.001, z1 - z0) > 0.6:
			top = maxf(top, v.y)
	return top


static func _relative(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
