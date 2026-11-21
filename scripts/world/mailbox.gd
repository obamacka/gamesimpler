## Mailbox: X opens the mail menu (spec 4.7, P5.13).
class_name Mailbox
extends WorldObject


func _ready() -> void:
	if add_art(self, "res://assets/third_party/kenney/survival_kit/signpost-single.glb", AABB(Vector3(-0.35, 0, -0.35), Vector3(0.7, 1.3, 0.7))) == null:
		add_child(box_mesh(Vector3(0.4, 1.1, 0.4), Color(0.2, 0.35, 0.7), Vector3(0, 0.55, 0)))
	make_interactable(String(name), &"MAILBOX", 1.0)


func unread() -> int:
	var s := session()
	return s.mail.model.unread_count() if s else 0


func interaction_spec(_player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	if alt:
		return null
	var spec := InteractionSpec.new(&"MAILBOX", 0.3)
	spec.opens_menu = &"mail"
	return spec


func resolve_interaction(_spec: InteractionSpec, _player: Node) -> void:
	pass
