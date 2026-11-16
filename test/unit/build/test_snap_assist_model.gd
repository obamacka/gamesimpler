# P3.15: snap assist (spec 2.7). Sockets are built by BuildGrid.world_sockets.
extends GdUnitTestSuite

var m: SnapAssistModel


func before_test() -> void:
	m = SnapAssistModel.new()


func _p(id: StringName) -> BuildPieceDef:
	return Database.pieces[id]


func _s(pos: Vector3, provides: StringName, key: String, cell := Vector3i(1, 0, 1), rot := 1) -> Dictionary:
	return {"position": pos, "provides": provides, "cell": cell, "rot": rot, "key": key}


func test_radius_matrix() -> void:
	for strength in 3:
		for furniture in [false, true]:
			m = SnapAssistModel.new()
			m.strength = strength
			var def := _p(&"piece_chair") if furniture else _p(&"piece_wall")
			var tag := &"wall_face" if furniture else &"wall_slot"
			var rad := SnapAssistModel.radius(strength, furniture)
			var s := _s(Vector3(2, 0, 2), tag, "a")
			assert_bool(m.resolve(def, Vector3(2 + rad - 0.01, 0, 2), [s], 0)["snapped"]).is_true()
			m.reset()
			assert_bool(m.resolve(def, Vector3(2 + rad + 0.01, 0, 2), [s], 0)["snapped"]).is_false()
	assert_float(SnapAssistModel.radius(2, false)).is_equal(0.60)
	assert_float(SnapAssistModel.radius(0, true)).is_equal(0.20)


func test_incompatible_tags_never_snap() -> void:
	var s := _s(Vector3(2, 0, 2), &"wall_face", "a")
	assert_bool(m.resolve(_p(&"piece_floor"), Vector3(2, 0, 2), [s], 0)["snapped"]).is_false()


func test_nearest_wins_and_stable_tie_break() -> void:
	var a := _s(Vector3(2, 0, 2), &"wall_slot", "b", Vector3i(1, 0, 1))
	var b := _s(Vector3(2.3, 0, 2), &"wall_slot", "a", Vector3i(2, 0, 2))
	assert_str(m.resolve(_p(&"piece_wall"), Vector3(2.1, 0, 2), [a, b], 0)["key"]).is_equal("b")
	m.reset()
	assert_str(m.resolve(_p(&"piece_wall"), Vector3(2.15, 0, 2), [a, b], 0)["key"]).is_equal("a")   # equal distance: lower key


func test_sticky_until_one_and_a_half_radius() -> void:
	var a := _s(Vector3(2, 0, 2), &"wall_slot", "a")
	var b := _s(Vector3(2.8, 0, 2), &"wall_slot", "b")
	assert_str(m.resolve(_p(&"piece_wall"), Vector3(2.1, 0, 2), [a, b], 0)["key"]).is_equal("a")
	assert_str(m.resolve(_p(&"piece_wall"), Vector3(2.6, 0, 2), [a, b], 0)["key"]).is_equal("a")   # nearer b, but sticky
	assert_str(m.resolve(_p(&"piece_wall"), Vector3(2.91, 0, 2), [a, b], 0)["key"]).is_equal("b")   # beyond 0.9 m


func test_auto_rotation_walls_on_floor_edges() -> void:
	var socks := BuildGrid.world_sockets(_p(&"piece_floor"), Vector3i(4, 0, 4), 0, "f").filter(func(s): return s["provides"] == &"wall_slot")
	var expected := {Vector3(4.5, 0.1, 4.98): 2, Vector3(4.5, 0.1, 4.02): 0, Vector3(4.98, 0.1, 4.5): 3, Vector3(4.02, 0.1, 4.5): 1}
	for pos in expected:
		m.reset()
		var r := m.resolve(_p(&"piece_wall"), pos + Vector3(0, 0.05, 0), socks, 0)
		assert_bool(r["snapped"]).is_true()
		assert_int(r["rot"]).is_equal(expected[pos])
		assert_vector(r["cell"]).is_equal(Vector3i(4, 0, 4))
		# The wall panel then sits on the floor edge the socket was on.
		var face := BuildGrid.edge_key(r["cell"], r["rot"])
		assert_str(face).is_equal(BuildGrid.edge_key(Vector3i(4, 0, 4), expected[pos]))


func test_auto_rotation_furniture_against_each_wall_face() -> void:
	for wall_rot in 4:
		m.reset()
		var socks := BuildGrid.world_sockets(_p(&"piece_wall"), Vector3i(4, 0, 4), wall_rot, "w")
		var face: Dictionary = socks.filter(func(s): return s["provides"] == &"wall_face")[0]
		var r := m.resolve(_p(&"piece_chair"), face["position"], socks, 0)
		assert_bool(r["snapped"]).is_true()
		assert_int(r["rot"]).is_equal(wall_rot)
		assert_vector(r["position"]).is_equal(face["position"])


func test_fallback_grid_with_manual_rotation() -> void:
	var r := m.resolve(_p(&"piece_chair"), Vector3(7.3, 0.2, 2.9), [], 3)
	assert_bool(r["snapped"]).is_false()
	assert_vector(r["cell"]).is_equal(Vector3i(7, 0, 2))
	assert_int(r["rot"]).is_equal(3)


func test_snapped_position_equals_socket_position() -> void:
	var s := _s(Vector3(2.25, 0.1, 2.75), &"floor_top", "a")
	assert_vector(m.resolve(_p(&"piece_table"), Vector3(2.3, 0.1, 2.7), [s], 0)["position"]).is_equal(Vector3(2.25, 0.1, 2.75))
