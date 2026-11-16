## Apple tree (spec 4.5 FORAGE, D8: never choppable). X or RT with the fruit picker picks it.
class_name AppleTree
extends WorldObject

@export var key := ""
@export var def_id: StringName = &"tree_apple"

var _fruit_mesh: MeshInstance3D


func _ready() -> void:
	if key == "":
		key = "%s/%s" % [SceneRouter.current_zone_id, name]
	add_child(box_mesh(Vector3(0.4, 2.0, 0.4), Color(0.45, 0.3, 0.15), Vector3(0, 1.0, 0)))
	add_child(box_mesh(Vector3(2.2, 1.6, 2.2), Color(0.3, 0.6, 0.25), Vector3(0, 2.6, 0)))
	_fruit_mesh = box_mesh(Vector3(2.3, 0.3, 2.3), Color(0.85, 0.15, 0.15), Vector3(0, 2.0, 0))
	add_child(_fruit_mesh)
	add_static_box(self, Vector3(0.4, 2.0, 0.4), Vector3(0, 1.0, 0))
	make_interactable(key, &"FORAGE", 1.6)
	make_tool_zone(key, ToolTypes.FRUIT_PICKER, &"fruit_tree", 20, 3.0)
	var s := session()
	if s:
		s.world_state.register_fruit_tree(key, def_id)
		s.terrain.rules.protect_support(base_cell(), key)


func _process(_delta: float) -> void:
	_fruit_mesh.visible = fruit() > 0


func fruit() -> int:
	var s := session()
	return s.world_state.fruit_count(key) if s else 0


func tool_zone_active() -> bool:
	return fruit() > 0


func interaction_spec(_player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	if alt or fruit() <= 0:
		return null
	return InteractionSpec.new(&"FORAGE", 1.2, Database.stamina.forage_cost)


func resolve_interaction(_spec: InteractionSpec, _player: Node) -> void:
	session().world_state.harvest_tree(key, global_position + Vector3(0, 1, 0))
