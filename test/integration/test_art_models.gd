# PA1.6: modelled pieces, stations, pickups and ripe crops show their art in the world
# (spec 11.3); collision still comes from the parts.
extends GdUnitTestSuite

const CELL := Vector3i(-8, 0, 15)

var h: Phase2Harness


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	BuildFixture.setup(h)
	h.place(Vector3(-7.5, 0, 13))
	h.aim_at_sky()


func after_test() -> void:
	h.stop()
	await get_tree().process_frame


func _view(uid: String) -> PieceView:
	return SceneRouter.current_zone.get_node("BuildView").views[uid]


func _shapes(v: PieceView) -> int:
	for c in v.get_children():
		if c is StaticBody3D:
			return c.get_child_count()
	return 0


func test_modelled_piece_replaces_boxes_and_keeps_collision() -> void:
	var uid := BuildFixture.place_fastened(h, &"piece_chair", CELL, 1)
	await h.frames(3)
	var v := _view(uid)
	assert_object(v.model).is_not_null()
	assert_str(v.model.name).is_equal("Model")
	assert_bool(v.meshes.is_empty()).is_false()
	assert_bool(v.meshes.all(func(m): return not (m.mesh is BoxMesh) and v.model.is_ancestor_of(m))).is_true()
	assert_int(_shapes(v)).is_equal(v.def.parts.filter(func(p): return p["solid"]).size())
	var mat: ShaderMaterial = v.meshes[0].material_override
	assert_bool(mat.get_shader_parameter(&"use_texture")).is_true()
	assert_object(mat.get_shader_parameter(&"albedo_tex")).is_not_null()
	assert_int(mat.get_shader_parameter(&"region")).is_equal(1)
	# unpainted keeps the texture; painting reaches every model mesh
	assert_that(v.meshes[0].get_instance_shader_parameter(&"primary_color")).is_equal(PaintModel.UNPAINTED)
	assert_bool(h.session.build.try_paint(uid, &"PRIMARY", &"dye_moss").ok).is_true()
	await h.frames(2)
	v = _view(uid)
	for m in v.meshes:
		assert_that(m.get_instance_shader_parameter(&"primary_color")).is_equal(Database.dyes[&"dye_moss"].color)


func test_placeholder_piece_still_uses_boxes() -> void:
	var uid := BuildFixture.place_fastened(h, &"piece_wall", CELL, 0)
	await h.frames(3)
	var v := _view(uid)
	assert_object(v.model).is_null()
	assert_bool(v.meshes.all(func(m): return m.mesh is BoxMesh)).is_true()


func test_unpainted_model_without_regions_is_region_none() -> void:
	var uid := BuildFixture.place_fastened(h, &"piece_fridge", CELL, 0)
	await h.frames(3)
	var mat: ShaderMaterial = _view(uid).meshes[0].material_override
	assert_int(mat.get_shader_parameter(&"region")).is_equal(0)
	assert_float(mat.get_shader_parameter(&"lighten")).is_equal(0.0)


## Builds the town's stations from home_meadow.tscn's saved properties (the harness runs a
## fixture zone, and the real one needs the voxel terrain).
func _town_station(node_name: String) -> MenuStation:
	var state := (load("res://scenes/zones/home_meadow.tscn") as PackedScene).get_state()
	for i in state.get_node_count():
		if state.get_node_name(i) != node_name:
			continue
		var st := MenuStation.new()
		for k in state.get_node_property_count(i):
			var prop := state.get_node_property_name(i, k)
			if prop in [&"kind", &"shop_id", &"model", &"model_yaw_deg", &"size", &"color"]:
				st.set(prop, state.get_node_property_value(i, k))
		st.name = node_name
		SceneRouter.current_zone.add_child(st)
		return st
	return null


func test_town_stations_show_models_over_box_colliders() -> void:
	for n in ["GeneralStore", "BuilderSupply", "TailorShop", "Workbench", "TailorBench"]:
		var st := _town_station(n)
		assert_object(st).override_failure_message(n).is_not_null()
		assert_str(st.model).override_failure_message(n).contains("kaykit/restaurant_bits")
		assert_str(st.visual.name).override_failure_message(n).is_equal("Model")
		assert_bool(st.get_children().any(func(c): return c is StaticBody3D)).is_true()
		var b: AABB = st.visual.transform * ModelFit.local_aabb(st.visual)
		assert_float(st.visual.transform.basis.get_scale().x).is_equal_approx(ModelFit.WORLD_SCALE, 0.0001)
		assert_bool(st.size.is_equal_approx(b.size)).override_failure_message(n).is_true()
		st.queue_free()
	var board := _town_station("JobBoard")
	assert_bool(board.visual is MeshInstance3D and (board.visual as MeshInstance3D).mesh is BoxMesh).is_true()
	board.queue_free()


func test_pickup_and_ripe_crop_use_produce_models() -> void:
	var p := Pickup.new()
	p.item_id = &"item_carrot"
	SceneRouter.current_zone.add_child(p)
	assert_str(String(p.get_node("Visual").get_meta(ItemVisual.MODEL_META, ""))).contains("food_ingredient_carrot")
	var stone := Pickup.new()
	stone.item_id = &"item_stone"
	SceneRouter.current_zone.add_child(stone)
	assert_bool(stone.get_node("Visual") is MeshInstance3D).is_true()
	# carrot has stage models (spec 11.9): no produce prop on top of the plant
	var crop: CropDef = Database.crops[&"crop_carrot"]
	var ripe: CropView = auto_free(CropView.new())
	ripe.setup(crop, 999)
	assert_bool(ripe.ripe).is_true()
	assert_object(ripe.get_node_or_null("Produce")).is_null()
	assert_object(ripe.model).is_not_null()
	# cotton has no models: the box, and no produce model either
	var cotton: CropView = auto_free(CropView.new())
	cotton.setup(Database.crops[&"crop_cotton"], 999)
	assert_object(cotton.model).is_null()
	assert_object(cotton.get_node_or_null("Produce")).is_null()
	p.queue_free()
	stone.queue_free()
