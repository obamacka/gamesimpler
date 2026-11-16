## Zone root (spec 9.2). Binds the terrain before children register (trees protect their
## support cells), registers protection volumes, and spawns chests and pickups.
class_name Zone
extends Node3D

const CHEST_SCENE := preload("res://scenes/props/treasure_chest.tscn")

@export var zone_id: StringName
@export var spawn_chests := true

var terrain_node: Node


func _enter_tree() -> void:
	var s := GameSession.current
	if s == null:
		return
	terrain_node = find_child("VoxelTerrain", false, false)
	if terrain_node:
		s.terrain.set_world(VoxelWorldAdapter.new(terrain_node))
	else:
		s.terrain.set_world(s.terrain.world)   # static or test zone: fresh rules on the current world
	var z: TerrainZoneDef = Database.zones.get(zone_id)
	if z:
		s.terrain.rules.bounds_min_y = z.bounds_min.y


func _ready() -> void:
	var s := GameSession.current
	if s == null:
		return
	for v in find_children("*", "ProtectionVolume", true, false):
		s.terrain.rules.add_volume(v.min_cell, v.max_cell, v.reason, v.allows_place)
	if spawn_chests:
		for key in s.world_state.chests:
			if StringName(s.world_state.chests[key]["zone"]) == zone_id:
				var c: Array = s.world_state.chests[key]["cell"]
				_spawn_chest(key, Vector3i(c[0], c[1], c[2]))
	EventBus.chest_spawned.connect(_on_chest_spawned)
	s.world_state.pickup_requested.connect(_on_pickup)


func _exit_tree() -> void:
	if EventBus.chest_spawned.is_connected(_on_chest_spawned):
		EventBus.chest_spawned.disconnect(_on_chest_spawned)
	var s := GameSession.current
	if s and s.world_state.pickup_requested.is_connected(_on_pickup):
		s.world_state.pickup_requested.disconnect(_on_pickup)


func _on_chest_spawned(key: String, cell: Vector3i) -> void:
	if key.begins_with(String(zone_id) + "/"):
		_spawn_chest(key, cell)


func _spawn_chest(key: String, cell: Vector3i) -> void:
	var c: TreasureChest = CHEST_SCENE.instantiate()
	c.key = key
	c.name = key.get_file()
	add_child(c)
	c.global_position = Vector3(cell) + Vector3(0.5, 0.0, 0.5)


func _on_pickup(item_id: StringName, qty: int, at: Vector3) -> void:
	var p := Pickup.new()
	p.item_id = item_id
	p.qty = qty
	add_child(p)
	p.global_position = at
