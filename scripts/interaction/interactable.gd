## Interaction area on layer `interactables` (spec 4.5). The owning object (parent) implements:
##   interaction_spec(player, forage: bool, alt: bool) -> InteractionSpec (or null)
##   resolve_interaction(spec: InteractionSpec, player) -> void
class_name Interactable
extends Area3D

const LAYER := 16   # layer 5

@export var key := ""
@export var kind: StringName = &"GENERIC"
@export var radius := 1.0


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	if get_child_count() == 0:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		shape.shape = sphere
		add_child(shape)


func spec_for(player: Node, forage: bool, alt: bool) -> InteractionSpec:
	var o := get_parent()
	return o.interaction_spec(player, forage, alt) if o.has_method("interaction_spec") else null


func resolve(spec: InteractionSpec, player: Node) -> void:
	var o := get_parent()
	if o.has_method("resolve_interaction"):
		o.resolve_interaction(spec, player)
