## Bed: X asks "Sleep until morning?" then hands off to Sleep(bed); Y sets it as home
## (spec 4.5, 7.3). Node name is the bed key used as spawn marker.
class_name Bed
extends WorldObject


func _ready() -> void:
	add_child(box_mesh(Vector3(1.2, 0.5, 2.2), Color(0.55, 0.55, 0.8), Vector3(0, 0.25, -1.4)))
	make_interactable(String(name), &"BED", 1.4, Vector3(0, 0.6, -1.4))


func interaction_spec(_player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	var spec := InteractionSpec.new(&"SET_HOME" if alt else &"BED", 0.0)
	spec.opens_menu = &"confirm"
	spec.menu_args = {"text": "Make this bed your home?" if alt else "Sleep until morning?", "default_yes": not alt}
	return spec


func resolve_interaction(spec: InteractionSpec, player: Node) -> void:
	if spec.menu_result != &"yes":
		return
	if spec.kind == &"BED":
		player.pending_sleep_reason = &"bed"
		spec.handoff_state = &"sleep"
	else:
		session().housing.set_home_bed(SceneRouter.current_zone_id, StringName(name))
