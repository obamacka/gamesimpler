## Proximity tool target (spec 2.6): trees, logs, loose build pieces. Layer `tool_zones`.
## The owner may implement tool_zone_active() -> bool.
class_name ToolTargetZone
extends Area3D

const LAYER := 32   # layer 6

@export var key := ""
@export var tool: StringName = ToolTypes.AXE
@export var target_kind: StringName = &"timber"
@export var tool_priority := 20
@export var enter_radius := 2.5


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = enter_radius
	shape.shape = sphere
	add_child(shape)


func is_active() -> bool:
	var o := get_parent()
	return o.tool_zone_active() if o.has_method("tool_zone_active") else true


func as_candidate(from: Vector3, inside: bool) -> Dictionary:
	return {"key": key, "tool": tool, "target_kind": target_kind, "priority": tool_priority,
		"distance": from.distance_to(global_position), "enter_radius": enter_radius,
		"inside": inside, "active": is_active(), "node": self}
