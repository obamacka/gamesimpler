## Deep Mine entrance (spec D16): mine_entrance_confirm ("resets every morning"), then travel.
class_name MineEntrance
extends WorldObject

@export var target_zone: StringName = &"zone_deep_mine"
@export var target_spawn: StringName = &"spawn_entry"
## Optional model (spec 12.3, e.g. the KayKit mine) fitted into model_size; doors without one
## show a glowing mat on the ground so children see where to walk.
@export_file("*.gltf", "*.glb", "*.fbx") var model := ""
@export var model_size := Vector3(4, 3.5, 4)
@export var model_yaw_deg := 0
@export var model_offset := Vector3.ZERO   # e.g. set the mine back so its mouth is at the door

var mat: MeshInstance3D


func _ready() -> void:
	if not model.is_empty():
		add_art(self, model, AABB(model_offset + Vector3(-model_size.x * 0.5, 0, -model_size.z * 0.5), model_size), model_yaw_deg)
	mat = door_mat()
	add_child(mat)
	make_interactable(String(name), &"MINE_ENTRANCE", 1.4)


func interaction_spec(_player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	if alt:
		return null
	var spec := InteractionSpec.new(&"MINE_ENTRANCE", 0.0)
	if target_zone == &"zone_deep_mine":
		spec.opens_menu = &"mine_entrance_confirm"
	return spec


func resolve_interaction(spec: InteractionSpec, _player: Node) -> void:
	if spec.opens_menu == &"" or spec.menu_result == &"yes":
		SceneRouter.travel(target_zone, target_spawn)


## A soft glowing disc on the ground (spec 12.3): "walk here".
static func door_mat() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = "DoorMat"
	var c := CylinderMesh.new()
	c.top_radius = 0.75
	c.bottom_radius = 0.75
	c.height = 0.04
	m.mesh = c
	m.position = Vector3(0, 0.03, 0)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1.0, 0.85, 0.3, 0.55)
	m.material_override = sm
	return m


func _process(_delta: float) -> void:
	if mat and not Accessibility.reduce_motion():
		var a := 0.4 + 0.2 * sin(Time.get_ticks_msec() / 400.0)
		(mat.material_override as StandardMaterial3D).albedo_color.a = a
