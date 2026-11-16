## Bed: X sleeps (hands off to the Sleep state). Node name is the bed key used as spawn marker.
## Phase 3 adds the confirm dialog and Set Home.
class_name Bed
extends WorldObject


func _ready() -> void:
	add_child(box_mesh(Vector3(1.2, 0.5, 2.2), Color(0.55, 0.55, 0.8), Vector3(0, 0.25, -1.4)))
	make_interactable(String(name), &"BED", 1.4, Vector3(0, 0.6, -1.4))


func interaction_spec(_player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	return null if alt else InteractionSpec.new(&"BED", 0.0, 0, &"sleep")


func resolve_interaction(_spec: InteractionSpec, player: Node) -> void:
	player.pending_sleep_reason = &"bed"
