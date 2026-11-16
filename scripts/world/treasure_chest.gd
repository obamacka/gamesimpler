## Buried treasure revealed by digging (spec 6.4). X opens it.
class_name TreasureChest
extends WorldObject

@export var key := ""


func _ready() -> void:
	add_child(box_mesh(Vector3(0.8, 0.6, 0.6), Color(0.65, 0.42, 0.15), Vector3(0, 0.3, 0)))
	make_interactable(key, &"CHEST", 1.0, Vector3(0, 0.4, 0))


func interaction_spec(_player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	return null if alt else InteractionSpec.new(&"CHEST", 1.0)


func resolve_interaction(_spec: InteractionSpec, _player: Node) -> void:
	var reward := session().world_state.open_chest(key, global_position + Vector3(0, 0.5, 0))
	if MenuStack.instance and not reward.is_empty():
		MenuStack.instance.push(&"chest_reveal", {"reward": reward})   # spec 6.4: unlock card
	queue_free()
