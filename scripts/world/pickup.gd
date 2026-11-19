## Dropped items that did not fit the inventory (K1). X picks them up.
class_name Pickup
extends WorldObject

@export var item_id: StringName
@export var qty := 1


func _ready() -> void:
	var v := ItemVisual.make(item_id, 0.3, Color(0.95, 0.85, 0.3))
	v.name = "Visual"
	add_child(v)
	make_interactable("pickup:%d" % get_instance_id(), &"PICKUP", 0.8, Vector3(0, 0.3, 0))


func interaction_spec(_player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	return null if alt else InteractionSpec.new(&"PICKUP", 0.4)


func resolve_interaction(_spec: InteractionSpec, _player: Node) -> void:
	var left := session().inventory.add(item_id, qty)
	if left == 0:
		queue_free()
	else:
		qty = left
