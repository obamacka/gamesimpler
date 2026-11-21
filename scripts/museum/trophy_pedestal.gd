## Trophy pedestal (spec 3.7): an empty plinth until its trophy unlocks, then a statue.
class_name TrophyPedestal
extends WorldObject

@export var trophy_id: StringName

var statue: MeshInstance3D


func _ready() -> void:
	if add_art(self, "res://assets/third_party/kaykit/furniture_bits/table_small.gltf", AABB(Vector3(-0.45, 0, -0.45), Vector3(0.9, 0.9, 0.9))) == null:
		add_child(box_mesh(Vector3(0.8, 0.9, 0.8), Color(0.7, 0.7, 0.72), Vector3(0, 0.45, 0)))
	add_static_box(self, Vector3(0.8, 0.9, 0.8), Vector3(0, 0.45, 0))
	EventBus.trophy_unlocked.connect(_on_trophy)
	refresh()


func _exit_tree() -> void:
	if EventBus.trophy_unlocked.is_connected(_on_trophy):
		EventBus.trophy_unlocked.disconnect(_on_trophy)


func _on_trophy(_id: StringName) -> void:
	refresh()


func refresh() -> void:
	var s := session()
	var on := s != null and String(trophy_id) in s.museum.model.trophies_unlocked
	if on and statue == null:
		statue = box_mesh(Vector3(0.35, 0.7, 0.35), Color(0.95, 0.8, 0.25), Vector3(0, 1.25, 0))
		add_child(statue)
