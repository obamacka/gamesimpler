## Deep Mine entrance (spec D16). Phase 3 adds the confirm dialog.
class_name MineEntrance
extends WorldObject

@export var target_zone: StringName = &"zone_deep_mine"
@export var target_spawn: StringName = &"spawn_entry"


func _ready() -> void:
	add_child(box_mesh(Vector3(2.0, 3.0, 0.3), Color(0.25, 0.2, 0.15), Vector3(0, 1.5, 0)))
	make_interactable(String(name), &"MINE_ENTRANCE", 1.4)


func interaction_spec(_player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	return null if alt else InteractionSpec.new(&"MINE_ENTRANCE", 0.0)


func resolve_interaction(_spec: InteractionSpec, _player: Node) -> void:
	SceneRouter.travel(target_zone, target_spawn)
