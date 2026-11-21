# PD2: houses assembled from Quaternius Village modules (spec 12.8).
extends GdUnitTestSuite

const BUILDINGS := "res://scenes/art/buildings/"


func _cfg(w: int, d: int, st: int, roof := "gable") -> Dictionary:
	return {"width": w, "depth": d, "storeys": st, "styles": PackedStringArray(["brick", "plaster"]), "door_module": -1,
		"round_door": true, "windows": true, "chimney": true, "roof": roof}


func _count(layout: Array[Dictionary], prefix: String) -> int:
	return layout.filter(func(e): return String(e["piece"]).begins_with(prefix)).size()


func test_one_storey_layout() -> void:
	var l := VillageHouse.layout(_cfg(3, 2, 1))
	assert_int(_count(l, "Wall_")).is_equal(2 * (3 + 2))
	assert_int(_count(l, "Door_")).is_equal(1)
	assert_int(_count(l, "Floor_")).is_equal(6)
	assert_int(_count(l, "Corner_")).is_equal(4)
	assert_int(_count(l, "Roof_RoundTiles_6x4")).is_equal(1)
	assert_int(_count(l, "Roof_Front_Brick6")).is_equal(2)
	assert_int(_count(l, "Prop_Chimney")).is_equal(1)
	# the door wall is the middle front module, at the front face (+Z)
	var door: Dictionary = l.filter(func(e): return String(e["piece"]).contains("_Door_"))[0]
	assert_vector(door["pos"]).is_equal(Vector3(0, 0, 2))


func test_walls_face_out_on_every_side() -> void:
	for e: Dictionary in VillageHouse.layout(_cfg(2, 3, 1)):
		if not String(e["piece"]).begins_with("Wall_"):
			continue
		var p: Vector3 = e["pos"]
		var expect := 0 if is_equal_approx(p.z, 3.0) else (180 if is_equal_approx(p.z, -3.0) else (-90 if p.x < 0 else 90))
		assert_int(int(e["yaw"])).override_failure_message(str(e)).is_equal(expect)


func test_upper_storeys_have_walls_but_one_door() -> void:
	var l := VillageHouse.layout(_cfg(2, 2, 3, "tower"))
	assert_int(_count(l, "Wall_")).is_equal(3 * 8)
	assert_int(_count(l, "Door_")).is_equal(1)
	assert_int(_count(l, "Roof_Tower_RoundTiles")).is_equal(1)
	assert_int(_count(l, "Roof_Front")).is_equal(0)
	var upper := l.filter(func(e): return String(e["piece"]).begins_with("Wall_") and e["pos"].y > 5.0)
	assert_bool(upper.all(func(e): return String(e["piece"]).contains("Plaster"))).is_true()   # last style repeats
	var ground := l.filter(func(e): return String(e["piece"]).begins_with("Wall_") and e["pos"].y < 1.0)
	assert_bool(ground.all(func(e): return String(e["piece"]).contains("UnevenBrick"))).is_true()


func test_collision_box_is_the_walls_and_door_point_is_in_front() -> void:
	var c := _cfg(3, 2, 2)
	assert_that(VillageHouse.box_for(c)).is_equal(AABB(Vector3(-3, 0, -2), Vector3(6, 6, 4)))
	assert_vector(VillageHouse.door_point_for(c)).is_equal(Vector3(0, 0, 2.6))


func test_every_prefab_piece_exists() -> void:
	for f in DirAccess.get_files_at(BUILDINGS):
		if not f.ends_with(".tscn"):
			continue
		var n: Node = (load(BUILDINGS + f) as PackedScene).instantiate()
		if n is VillageHouse:
			for e: Dictionary in VillageHouse.layout((n as VillageHouse).config()):
				var path := VillageHouse.DIR + String(e["piece"]) + ".gltf"
				assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
		n.free()


func test_house_in_tree_builds_and_reports_its_box() -> void:
	var h: VillageHouse = auto_free((load(BUILDINGS + "cabin.tscn") as PackedScene).instantiate())
	add_child(h)
	assert_int(h.get_child_count()).is_equal(VillageHouse.layout(h.config()).size())
	assert_that(h.collision_box()).is_equal(AABB(Vector3(-3, 0, -2), Vector3(6, 3, 4)))
	# the roof overhangs the walls; the collider must not
	var b := ModelFit.local_aabb(h)
	assert_float(b.size.x).is_greater(6.5)


## Spec 12.8: the KayKit packs are gone; no scene, script or data file may point at them.
func test_nothing_references_kaykit() -> void:
	var hits: Array[String] = []
	for root in ["res://scenes", "res://scripts", "res://ui", "res://resources"]:
		_scan(root, hits)
	assert_array(hits).is_empty()


func _scan(dir: String, hits: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in ["gd", "tscn", "tres", "json"]:
			if FileAccess.get_file_as_string(dir.path_join(f)).contains("third_party/kaykit"):
				hits.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), hits)
