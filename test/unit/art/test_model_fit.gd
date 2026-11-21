# PA1.6: art models load, fit their boxes and face the build convention (spec 11.3).
extends GdUnitTestSuite

const EPS := 0.002


func _modelled() -> Array:
	return Database.pieces.values().filter(func(p): return p.has_model())


func _fitted(def: BuildPieceDef) -> Node3D:
	var holder: Node3D = auto_free(Node3D.new())
	var m := ModelFit.instantiate(def.model_scene)
	holder.add_child(m)
	ModelFit.place(m, def.placement_box(), def.model_yaw_deg)
	return holder


## AABB of the model in holder space.
func _bounds(holder: Node3D) -> AABB:
	var m: Node3D = holder.get_child(0)
	return m.transform * ModelFit.local_aabb(m)


func test_furniture_is_wired() -> void:
	for id in [&"piece_chair", &"piece_sofa", &"piece_table", &"piece_bed", &"piece_lamp", &"piece_shelf", &"piece_chest",
			&"piece_armchair", &"piece_bed_double", &"piece_cabinet", &"piece_plant", &"piece_counter", &"piece_stove", &"piece_fridge"]:
		assert_bool(Database.pieces[id].has_model()).override_failure_message(String(id)).is_true()
	assert_bool(Database.pieces[&"piece_wall"].has_model()).is_false()


## Spec 11.4: one world scale; the model stands on its placement floor, overhangs its
## footprint by at most MAX_OVERHANG per side, and the collision parts cover it in x and z.
func test_every_model_is_at_world_scale_inside_its_footprint() -> void:
	assert_int(_modelled().size()).is_greater_equal(14)
	for def: BuildPieceDef in _modelled():
		var holder := _fitted(def)
		var m: Node3D = holder.get_child(0)
		var b := _bounds(holder)
		var fp := def.footprint_box()
		var msg := "%s model %s footprint %s" % [def.id, b, fp]
		assert_float(m.transform.basis.get_scale().x).override_failure_message(msg).is_equal_approx(ModelFit.WORLD_SCALE, 0.0001)
		assert_float(b.position.y).override_failure_message(msg).is_equal_approx(def.placement_box().position.y, EPS)
		for axis in [0, 2]:
			assert_bool(b.position[axis] >= fp.position[axis] - ModelFit.MAX_OVERHANG - EPS).override_failure_message(msg).is_true()
			assert_bool(b.end[axis] <= fp.end[axis] + ModelFit.MAX_OVERHANG + EPS).override_failure_message(msg).is_true()
			# the footprint is the smallest one allowed: one cell fewer would overhang too far
			if fp.size[axis] > 1.0:
				assert_bool(b.size[axis] - (fp.size[axis] - 1.0) > 2.0 * ModelFit.MAX_OVERHANG).override_failure_message(msg).is_true()
		var pb := def.parts_box()
		for axis in [0, 2]:
			assert_float(pb.position[axis]).override_failure_message(msg).is_equal_approx(b.position[axis], 0.01)
			assert_float(pb.end[axis]).override_failure_message(msg).is_equal_approx(b.end[axis], 0.01)


func test_models_only_use_their_own_buffers_and_pack_texture() -> void:
	for def: BuildPieceDef in _modelled():
		var text := FileAccess.get_file_as_string(def.model_scene)
		var gltf: Dictionary = JSON.parse_string(text)
		assert_bool(gltf.has("extensionsRequired")).override_failure_message(def.model_scene).is_false()
		for key in ["buffers", "images"]:
			for e in gltf.get(key, []):
				var uri := String(e.get("uri", ""))
				assert_bool(uri.contains("/") or uri.contains(":") or uri.contains("\\")).override_failure_message(uri).is_false()
				assert_bool(FileAccess.file_exists(def.model_scene.get_base_dir().path_join(uri))).override_failure_message(uri).is_true()


## Seats and beds: the high parts (backrest, headboard) end up behind the middle, at -z
## in the piece's unrotated frame (spec 1.6, 11.3).
func test_seating_and_beds_face_plus_z() -> void:
	var checked := 0
	for def: BuildPieceDef in _modelled():
		if def.interaction(&"SIT").is_empty() and def.interaction(&"SLEEP").is_empty():
			continue
		if not def.interaction(&"SIT").is_empty() and def.parts.size() < 2:
			continue   # benches and stools have no backrest (spec 12.8)
		var holder := _fitted(def)
		var m: Node3D = holder.get_child(0)
		var b := _bounds(holder)
		var cut := b.position.y + b.size.y * 0.75
		var acc := Vector3.ZERO
		var n := 0
		for mi in ModelFit.mesh_instances(m):
			var xf := m.transform * _rel(m, mi)
			for v in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var w: Vector3 = xf * v
				if w.y >= cut:
					acc += w
					n += 1
		assert_int(n).is_greater(0)
		var top_z := acc.z / float(n)
		assert_bool(top_z < b.get_center().z - 0.05).override_failure_message("%s back at z %.2f, centre %.2f" % [def.id, top_z, b.get_center().z]).is_true()
		checked += 1
	assert_int(checked).is_greater_equal(3)


func _rel(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## Seats sit on the model's seat (spec 12.8: highest point over the front 40%), at a
## sitting height, on top of the seat part.
func test_seat_heights_match_the_seat_parts() -> void:
	for def: BuildPieceDef in _modelled():
		var sit := def.interaction(&"SIT")
		if sit.is_empty():
			continue
		var holder := _fitted(def)
		var m: Node3D = holder.get_child(0)
		var want := ModelFit.seat_height(m, m.transform)
		for s in sit.get("seats", []):
			assert_float(s.y).override_failure_message(String(def.id)).is_equal_approx(want, 0.002)
			assert_bool(s.y > 0.35 and s.y < 0.65).override_failure_message(String(def.id)).is_true()
			var top := 0.0
			for p in def.parts:
				var lo: Vector3 = p["center"] - p["size"] * 0.5
				var hi: Vector3 = p["center"] + p["size"] * 0.5
				if s.x >= lo.x and s.x <= hi.x and s.z >= lo.z and s.z <= hi.z:
					top = maxf(top, hi.y) if hi.y <= s.y + 0.01 else top
			assert_float(s.y).override_failure_message(String(def.id)).is_equal_approx(top, 0.01)


func test_fit_turns_and_scales() -> void:
	var m := ModelFit.instantiate("res://assets/third_party/quaternius/props/Bench.gltf")
	var holder: Node3D = auto_free(Node3D.new())
	holder.add_child(m)
	var s := ModelFit.fit(m, AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2)), 90)
	var b := _bounds(holder)
	# the 2.78 m bench turned a quarter: its long side runs along z
	assert_float(s).is_equal_approx(2.0 / 2.777, 0.002)
	assert_float(b.size.z).is_equal_approx(2.0, EPS)
	assert_bool(b.size.x < b.size.z).is_true()
	assert_float(b.position.y).is_equal_approx(0.0, EPS)
	assert_float(b.get_center().x).is_equal_approx(0.0, EPS)


func test_missing_model_is_null_and_caught_by_validation() -> void:
	assert_object(ModelFit.instantiate("res://assets/missing.gltf")).is_null()
	assert_object(ModelFit.instantiate("")).is_null()
	var def: BuildPieceDef = Database.pieces[&"piece_chair"]
	var old := def.model_scene
	def.model_scene = "res://assets/missing.gltf"
	var errors := Database.validate()
	def.model_scene = old
	assert_bool(errors.any(func(e): return e.contains("piece_chair model"))).is_true()


func test_modelled_pieces_paint_primary_only() -> void:
	for def: BuildPieceDef in _modelled():
		for r in def.paint_regions:
			assert_str(r["region_id"]).override_failure_message(String(def.id)).is_equal(&"PRIMARY")
	var it: ItemDef = Database.items[&"item_seed_carrot"]
	var old := it.world_model
	it.world_model = "res://assets/missing.gltf"
	var errors := Database.validate()
	it.world_model = old
	assert_bool(errors.any(func(e): return e.contains("item_seed_carrot world model"))).is_true()


func test_item_visual_uses_world_model_or_box() -> void:
	var carrot: Node3D = auto_free(ItemVisual.make(&"item_carrot", 0.4, Color.RED))
	assert_str(String(carrot.get_meta(ItemVisual.MODEL_META, ""))).contains("props/Carrot")
	var b: AABB = (carrot.get_child(0) as Node3D).transform * ModelFit.local_aabb(carrot.get_child(0))
	assert_float(maxf(b.size.x, maxf(b.size.y, b.size.z))).is_equal_approx(0.4, EPS)
	assert_float(b.position.y).is_equal_approx(0.0, EPS)
	var stone: Node3D = auto_free(ItemVisual.make(&"item_stone", 0.3, Color.RED))
	assert_bool(stone is MeshInstance3D).is_true()
	assert_bool(stone.has_meta(ItemVisual.MODEL_META)).is_false()
