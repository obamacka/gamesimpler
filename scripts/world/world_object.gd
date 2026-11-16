## Helpers shared by world objects (trees, chests, beds...).
class_name WorldObject
extends Node3D


static func session() -> GameSession:
	return GameSession.current


static func box_mesh(size: Vector3, color: Color, offset: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	m.mesh = bm
	m.position = offset
	return m


static func add_static_box(parent: Node3D, size: Vector3, offset: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var s := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	s.shape = box
	b.add_child(s)
	b.position = offset
	parent.add_child(b)
	return b


func make_interactable(key: String, kind: StringName, radius: float = 1.2, offset: Vector3 = Vector3(0, 1, 0)) -> Interactable:
	var i := Interactable.new()
	i.key = key
	i.kind = kind
	i.radius = radius
	i.position = offset
	add_child(i)
	return i


func make_tool_zone(key: String, tool: StringName, target_kind: StringName, priority: int, radius: float) -> ToolTargetZone:
	var z := ToolTargetZone.new()
	z.key = key
	z.tool = tool
	z.target_kind = target_kind
	z.tool_priority = priority
	z.enter_radius = radius
	z.position = Vector3(0, 1, 0)
	add_child(z)
	return z


func base_cell() -> Vector3i:
	return IVoxelWorld.cell_of(global_position + Vector3(0, 0.01, 0))
