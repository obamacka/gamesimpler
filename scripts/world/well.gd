## Well (spec 10.3): refills the watering can. RT with the can (tool zone `refill`) or X.
class_name Well
extends WorldObject

const ART := "res://scenes/art/buildings/well.tscn"   # Quaternius pieces (spec 12.8)


func _ready() -> void:
	if add_art_at(self, ART) == null:
		add_child(box_mesh(Vector3(1.2, 0.9, 1.2), Color(0.5, 0.5, 0.55), Vector3(0, 0.45, 0)))
		add_child(box_mesh(Vector3(0.9, 0.05, 0.9), Color(0.2, 0.4, 0.8), Vector3(0, 0.88, 0)))
	add_static_box(self, Vector3(1.6, 0.8, 1.6), Vector3(0, 0.4, 0))
	make_tool_zone(String(name), ToolTypes.WATERING_CAN, &"refill", 15, 1.6)
	make_interactable(String(name), &"REFILL", 1.4)


func interaction_spec(_player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	var s := session()
	if alt or s == null or not s.toolbelt.model.has_tool(ToolTypes.WATERING_CAN):
		return null
	return InteractionSpec.new(&"REFILL", 0.3)


func resolve_interaction(_spec: InteractionSpec, _player: Node) -> void:
	session().farm.refill_can()
