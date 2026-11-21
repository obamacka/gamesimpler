# PD2: the town's Quaternius houses (spec 12.8): wall colliders and doors at the zone doors.
extends GdUnitTestSuite

var h: Phase2Harness


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	SceneRouter.overrides.erase(&"zone_home_meadow")   # the real town, not the test fixture
	await SceneRouter.change_zone(&"zone_home_meadow", &"spawn_start")
	await h.frames(3)


func after_test() -> void:
	h.stop()
	await get_tree().process_frame


func _surface(n: String) -> Node3D:
	return SceneRouter.current_zone.get_node("Surface/" + n)


func _house(holder_parent: Node3D) -> VillageHouse:
	return holder_parent.get_node("Art").get_child(0) as VillageHouse


func _collider(n: Node3D) -> BoxShape3D:
	for c in n.get_children():
		if c is StaticBody3D:
			return (c.get_child(0) as CollisionShape3D).shape as BoxShape3D
	return null


func test_houses_are_built_with_wall_colliders() -> void:
	for n in ["CabinExterior", "Museum", "Workshop", "Tavern", "TailorHouse", "Tower", "NeighborHouse"]:
		var node := _surface(n)
		var house := _house(node)
		assert_object(house).override_failure_message(n).is_not_null()
		assert_int(house.get_child_count()).override_failure_message(n).is_greater(10)
		var box := _collider(node)
		assert_object(box).override_failure_message(n).is_not_null()
		assert_vector(box.size).override_failure_message(n).is_equal_approx(house.collision_box().size, Vector3.ONE * 0.01)


func test_zone_doors_sit_at_the_house_doors() -> void:
	for pair in [["CabinExterior", "CabinDoor"], ["Museum", "MuseumDoor"]]:
		var node := _surface(pair[0])
		var door := _surface(pair[1])
		var house := _house(node)
		var want := house.global_transform * house.door_point()
		var got := door.global_position
		assert_float(Vector2(want.x, want.z).distance_to(Vector2(got.x, got.z))).override_failure_message(str(pair)).is_less(0.15)


func test_well_and_market_use_quaternius_art() -> void:
	assert_str(_surface("Well").get_node("Art").get_child(0).scene_file_path).is_equal("res://scenes/art/buildings/well.tscn")
	assert_str(_surface("Market").get_node("Art").get_child(0).scene_file_path).is_equal("res://scenes/art/buildings/market.tscn")
