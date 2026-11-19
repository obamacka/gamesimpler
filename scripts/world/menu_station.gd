## An interactable that opens a menu (spec 4.5 table): SHOP, JOB_BOARD, WORKBENCH,
## TAILOR_BENCH, WARDROBE, PLOT_SIGN. Benches hand off to Craft for timed recipes.
class_name MenuStation
extends WorldObject

const MENUS := {&"DONATE": &"donation", &"SHOP": &"shop", &"JOB_BOARD": &"job_board", &"WORKBENCH": &"crafting",
	&"TAILOR_BENCH": &"crafting", &"WARDROBE": &"outfit_customizer", &"PLOT_SIGN": &"house_purchase"}

@export var kind: StringName = &"SHOP"
@export var shop_id: StringName = &"shop_general"
@export var job_id: StringName = &""
@export var plot_id: StringName = &""
@export var color := Color(0.6, 0.45, 0.3)
@export var size := Vector3(1.6, 1.1, 0.8)
## Optional art model (spec 11.3) fitted into `size`; the box collider stays.
@export_file("*.gltf", "*.glb", "*.tscn") var model := ""
@export var model_yaw_deg := 0

var visual: Node3D


func _ready() -> void:
	visual = ModelFit.instantiate(model)
	if visual:
		visual.name = "Model"
		add_child(visual)
		ModelFit.fit(visual, AABB(Vector3(-size.x * 0.5, 0, -size.z * 0.5), size), model_yaw_deg)
	else:
		visual = box_mesh(size, color, Vector3(0, size.y * 0.5, 0))
		add_child(visual)
	add_static_box(self, size, Vector3(0, size.y * 0.5, 0))
	make_interactable(String(name), kind, 1.6)


func menu_args() -> Dictionary:
	match kind:
		&"SHOP": return {"shop_id": shop_id}
		&"JOB_BOARD": return {"job_id": job_id}
		&"WORKBENCH", &"TAILOR_BENCH": return {"station": kind}
		&"PLOT_SIGN": return {"plot_id": plot_id}
	return {}


func interaction_spec(_player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	if alt:
		return null
	var spec := InteractionSpec.new(kind, 0.2)
	spec.opens_menu = MENUS[kind]
	spec.menu_args = menu_args()
	return spec


func resolve_interaction(spec: InteractionSpec, player: Node) -> void:
	var r = spec.menu_result
	if r is Dictionary and r.get("handoff", &"") == &"craft":
		player.pending_craft = {"recipe": r["recipe"], "station": r.get("station", kind)}
		spec.handoff_state = &"craft"
