## Mailbox. Phase 2: X claims all letters (temporary, replaced by the mail menu in P5.13).
class_name Mailbox
extends WorldObject


func _ready() -> void:
	add_child(box_mesh(Vector3(0.4, 1.1, 0.4), Color(0.2, 0.35, 0.7), Vector3(0, 0.55, 0)))
	make_interactable(String(name), &"MAILBOX", 1.0)


func unread() -> int:
	var s := session()
	return s.mail.model.unread_count() if s else 0


func interaction_spec(_player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	return null if alt else InteractionSpec.new(&"MAILBOX", 0.3)


func resolve_interaction(_spec: InteractionSpec, _player: Node) -> void:
	session().mail.claim_all()
