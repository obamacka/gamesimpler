## Zone root (spec 9.2). Binds the terrain before children register (trees protect their
## support cells), registers protection volumes, and spawns chests and pickups.
class_name Zone
extends Node3D

const CHEST_SCENE := preload("res://scenes/props/treasure_chest.tscn")

@export var zone_id: StringName
@export var spawn_chests := true
## &"overworld" or &"deep_mine" generates a VoxelTerrain at load; empty = static or test zone.
@export var terrain_kind: StringName = &""
@export var view_distance := 96

var terrain_node: Node
var generator: VoxelGeneratorScript


func _enter_tree() -> void:
	var s := GameSession.current
	if s == null:
		return
	terrain_node = find_child("VoxelTerrain", false, false)
	if terrain_node == null and terrain_kind != &"":
		terrain_node = _make_terrain(s)
		_snap_surface_children()
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
	s.farm.bind_zone(zone_id, self)
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


func _material_ids() -> Dictionary:
	var ids := {}
	for m in Database.materials.values():
		ids[String(m.id)] = m.voxel_id
	return ids


func _make_terrain(s: GameSession) -> Node:
	var z: TerrainZoneDef = Database.zones.get(zone_id)
	var bmin := z.bounds_min if z else Vector3i(-64, -32, -64)
	var bmax := z.bounds_max if z else Vector3i(64, 64, 64)
	if terrain_kind == &"deep_mine":
		generator = DeepMineGenerator.new(_material_ids(), bmin.y, bmax.y, DeepMineGenerator.day_seed(s.rng.seed_value, s.day()))
	else:
		var og := OverworldGenerator.new(_material_ids(), bmin.y, hash([s.rng.seed_value, String(zone_id)]))
		for p in Database.plots.values():
			if p.zone_id == zone_id:   # plots are level, with a 1-cell border
				var a: Vector3i = p.min_cell - Vector3i(1, 0, 1)
				var b: Vector3i = p.max_cell + Vector3i(2, 0, 2)
				og.add_flat(Rect2i(a.x, a.z, b.x - a.x, b.z - a.z))
		generator = og
	var t := VoxelTerrain.new()
	t.name = "VoxelTerrain"
	var mesher := VoxelMesherBlocky.new()
	mesher.library = VoxelLibraryBuilder.build()
	t.mesher = mesher
	t.generator = generator
	t.max_view_distance = view_distance
	t.bounds = AABB(Vector3(bmin), Vector3(bmax - bmin))
	t.generate_collisions = true
	add_child(t)
	return t


## Children of a "Surface" node are moved onto the generated ground (overworld zones).
func _snap_surface_children() -> void:
	var surface := find_child("Surface", false, false)
	if surface == null or not (generator is OverworldGenerator):
		return
	for n in surface.get_children():
		if n is Node3D:
			var p: Vector3 = n.position
			n.position.y = (generator as OverworldGenerator).height_at(floori(p.x), floori(p.z)) + 1


## Resolves once the terrain around `pos` is meshed (so collision exists), or after a timeout.
## Static zones resolve immediately.
func await_ground_ready(pos: Vector3, timeout_ms: int = 10000) -> void:
	if not (terrain_node is VoxelTerrain):
		return
	var t: VoxelTerrain = terrain_node
	var area := AABB(pos - Vector3(4, 6, 4), Vector3(8, 10, 8))
	var start := Time.get_ticks_msec()
	while not t.is_area_meshed(area):
		if Time.get_ticks_msec() - start > timeout_ms:
			push_warning("Zone %s: terrain around %s not meshed after %d ms" % [zone_id, pos, timeout_ms])
			return
		await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
