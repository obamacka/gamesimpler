# Navigation meshes (spec 9.4, owner request with Phase 6): a baked region lets NPCs and the
# pet route around obstacles instead of walking straight into them.
extends GdUnitTestSuite

var h: Phase2Harness


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	h.world.fill(Vector3i(-12, -1, -12), Vector3i(12, -1, 12), h.vid(&"mat_grass"))
	GameClock.model.set_time(3, 9 * 60)


func after_test() -> void:
	h.stop()
	await get_tree().process_frame


## A 6 m wall between z = 4 and z = -4.
func _wall() -> void:
	var w := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 3, 0.4)
	cs.shape = box
	w.add_child(cs)
	h.add_scene_node(w, Vector3(0, 1.5, 0))


func _bake() -> int:
	var zone: Zone = SceneRouter.current_zone
	var n := zone.bake_navigation_now(AABB(Vector3(-10, -2, -10), Vector3(20, 6, 20)), h.world)
	await h.frames(8)   # the navigation map needs a few physics iterations to sync
	return n


func test_bake_produces_a_detour_path() -> void:
	_wall()
	await h.frames(2)
	assert_int(await _bake()).is_greater(0)
	var map := h.player.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, Vector3(0.5, 0, 4), Vector3(0.5, 0, -4), true)
	assert_int(path.size()).is_greater(2)   # not a straight line through the wall
	var widest := 0.0
	for p in path:
		widest = maxf(widest, absf(p.x))
	assert_float(widest).is_greater(2.5)   # goes around the 6 m wall


func test_npc_walks_around_the_wall() -> void:
	_wall()
	var m := Marker3D.new()
	m.name = "npc_hilde_shop"
	h.add_scene_node(m, Vector3(0.5, 0, -4))
	await h.frames(2)
	await _bake()
	var npc := PetFixture.npc(h, &"npc_hilde", Vector3(0.5, 0, 4))
	npc.global_position = Vector3(0.5, 0, 4)
	var n := 0
	var widest := 0.0
	while npc.global_position.distance_to(m.global_position) > 0.5 and n < 900:
		await h.frames(5)
		n += 5
		widest = maxf(widest, absf(npc.global_position.x))
	assert_float(npc.global_position.distance_to(m.global_position)).is_less(0.6)
	assert_float(widest).is_greater(2.5)   # it went around the wall's end, not through or along it


func test_pet_navmesh_provider_routes_around() -> void:
	_wall()
	await h.frames(2)
	await _bake()
	var prov := NavmeshPathProvider.new(h.player.get_world_3d().navigation_map)
	var path := prov.find_path(Vector3(0.5, 0, 4), Vector3(0.5, 0, -4))
	assert_int(path.size()).is_greater(2)


func test_static_museum_bakes_on_load() -> void:
	var baked := [0]
	EventBus.navigation_baked.connect(func(n): baked[0] = n)
	await SceneRouter.change_zone(&"zone_museum", &"spawn_start")
	await h.frames(3)
	assert_int(baked[0]).is_greater(0)
	var zone: Zone = SceneRouter.current_zone
	assert_object(zone.navigation).is_not_null()
	var curator: Npc = zone.get_node("Npc_curator")
	var desk := SceneRouter.find_marker(&"npc_curator_desk")
	curator.global_position = Vector3(-6, 0, 8)
	var n := 0
	while curator.global_position.distance_to(desk.global_position) > 0.5 and n < 900:
		await h.frames(5)
		n += 5
	assert_float(curator.global_position.distance_to(desk.global_position)).is_less(0.6)


func test_voxel_faces_alone_bake_walkable_polygons() -> void:
	var w := FakeVoxelWorld.new()
	w.fill(Vector3i(0, 0, 0), Vector3i(7, 0, 7), h.vid(&"mat_grass"))
	var faces := ZoneNavigation.voxel_top_faces(w, AABB(Vector3(0, -1, 0), Vector3(8, 4, 8)))
	assert_int(faces.size()).is_equal(64 * 6)
	var src := NavigationMeshSourceGeometryData3D.new()
	src.add_faces(faces, Transform3D())
	var nm := NavigationMesh.new()
	nm.agent_radius = ZoneNavigation.AGENT_RADIUS
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	assert_int(nm.get_polygon_count()).is_greater(0)   # guards the face winding
