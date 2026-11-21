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
## Bake a navmesh for NPCs and the pet when the zone is loaded (spec 9.4).
@export var bake_navigation := true

var terrain_node: Node
var generator: VoxelGeneratorScript
var navigation: ZoneNavigation


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
	elif s.terrain.world is VoxelWorldAdapter:
		# STATIC zone after an overworld zone: the adapter's VoxelTerrain is being freed, so the
		# static zone gets an empty world instead of a dangling one.
		s.terrain.set_world(FakeVoxelWorld.new())
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
	s.build.bind_zone(zone_id, self)
	s.jobs.bind_zone(zone_id)
	if spawn_chests:
		for key in s.world_state.chests:
			if StringName(s.world_state.chests[key]["zone"]) == zone_id:
				var c: Array = s.world_state.chests[key]["cell"]
				_spawn_chest(key, Vector3i(c[0], c[1], c[2]))
	EventBus.chest_spawned.connect(_on_chest_spawned)
	EventBus.zone_loaded.connect(_on_zone_loaded)
	s.world_state.pickup_requested.connect(_on_pickup)


func _exit_tree() -> void:
	if EventBus.chest_spawned.is_connected(_on_chest_spawned):
		EventBus.chest_spawned.disconnect(_on_chest_spawned)
	if EventBus.zone_loaded.is_connected(_on_zone_loaded):
		EventBus.zone_loaded.disconnect(_on_zone_loaded)
	var s := GameSession.current
	if s and s.world_state.pickup_requested.is_connected(_on_pickup):
		s.world_state.pickup_requested.disconnect(_on_pickup)


func _on_zone_loaded(z: StringName) -> void:
	if z != zone_id or not bake_navigation:
		return
	var area := navigation_area()
	if terrain_node is VoxelTerrain and area.size != Vector3.ZERO:
		# Generated ground streams in asynchronously: wait until the town is meshed.
		var start := Time.get_ticks_msec()
		while is_inside_tree() and not (terrain_node as VoxelTerrain).is_area_meshed(area) and Time.get_ticks_msec() - start < 10000:
			await get_tree().process_frame
		if not is_inside_tree():
			return
	bake_navigation_now(area)


## Overworld: the bounding box of the TOWN protection volumes (NPCs live there). STATIC
## zones: their bounds. Returns the polygon count (0 when there is nothing to walk on).
func bake_navigation_now(aabb: AABB = AABB(), voxels: IVoxelWorld = null) -> int:
	var s := GameSession.current
	if voxels == null and terrain_kind != &"" and s:
		voxels = s.terrain.world
	if aabb.size == Vector3.ZERO:
		aabb = navigation_area()
	if aabb.size == Vector3.ZERO:
		return 0
	if navigation == null:
		navigation = ZoneNavigation.new()
		navigation.name = "Navigation"
		add_child(navigation)
	return navigation.bake_now(self, voxels, aabb)


func navigation_area() -> AABB:
	var box := AABB()
	var first := true
	if terrain_kind != &"":
		for v in find_children("*", "ProtectionVolume", true, false):
			if v.reason != &"TOWN":
				continue
			var b := AABB(Vector3(v.min_cell.x - 1, -40, v.min_cell.z - 1), Vector3(v.max_cell.x - v.min_cell.x + 3, 104, v.max_cell.z - v.min_cell.z + 3))
			box = b if first else box.merge(b)
			first = false
		if not first:
			var h := (generator as OverworldGenerator).height_at(int(box.get_center().x), int(box.get_center().z)) if generator is OverworldGenerator else 0
			box.position.y = h - 3
			box.size.y = 10
		return box
	var z: TerrainZoneDef = Database.zones.get(zone_id)
	var lo := z.bounds_min if z else Vector3i(-40, -4, -40)
	var hi := z.bounds_max if z else Vector3i(40, 10, 40)
	return AABB(Vector3(lo), Vector3(hi - lo))


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
		var town_h := -100000
		for v in find_children("*", "ProtectionVolume", true, false):
			if v.reason == &"TOWN":   # towns are level, at one height, so the baked navmesh is walkable (spec 9.4)
				town_h = og.add_flat(Rect2i(v.min_cell.x, v.min_cell.z, v.max_cell.x - v.min_cell.x + 1, v.max_cell.z - v.min_cell.z + 1), town_h)
		for v in find_children("*", "ProtectionVolume", true, false):
			if v.reason == &"BUILDING":   # buildings stand on a level pad (spec 12.3)
				og.add_flat(Rect2i(v.min_cell.x, v.min_cell.z, v.max_cell.x - v.min_cell.x + 1, v.max_cell.z - v.min_cell.z + 1))
		for bp in Database.blueprints.values():
			if bp.zone_id == zone_id:   # job sites are level too
				og.add_flat(Rect2i(bp.site_min.x, bp.site_min.z, bp.site_max.x - bp.site_min.x + 1, bp.site_max.z - bp.site_min.z + 1))
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
	if z and z.persist_edits and z.stream_db_key != "" and terrain_kind == &"overworld":
		# spec 9.6: stream from the working copy; SaveService copies it into the slot on save.
		VoxelPersistence.ensure_dir(SaveService.work_dir())
		var stream := VoxelStreamSQLite.new()
		stream.database_path = ProjectSettings.globalize_path(SaveService.work_dir().path_join(z.stream_db_key + ".sqlite"))
		t.stream = stream
	add_child(t)
	return t


## Called right before the zone is freed: the session must stop reading this zone's
## VoxelTerrain (raycasts from the tool selector, prompts, pet) once it is going away.
func detach() -> void:
	var s := GameSession.current
	if s and terrain_node and s.terrain.world is VoxelWorldAdapter:
		s.terrain.set_world(FakeVoxelWorld.new())


## Writes modified blocks to the working DB before the zone is freed (zone change).
func save_terrain() -> void:
	await VoxelPersistence.flush(self)


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
