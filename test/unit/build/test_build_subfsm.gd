# P3.16: Build sub-FSM (spec 4.4).
extends GdUnitTestSuite


func test_tool_cycle() -> void:
	var m := BuildModel.new()
	assert_str(m.tool).is_equal(BuildModel.PLACE)
	m.next_tool()
	assert_str(m.tool).is_equal(BuildModel.PAINT)
	assert_bool(m.tool_enabled()).is_true()   # Paint enabled in Phase 6
	m.next_tool()
	assert_str(m.tool).is_equal(BuildModel.STAMP)
	m.next_tool()
	assert_str(m.tool).is_equal(BuildModel.PLACE)
	m.prev_tool()
	assert_str(m.tool).is_equal(BuildModel.STAMP)


func test_catalog_returns_to_same_substate() -> void:
	var m := BuildModel.new()
	m.begin_fasten()
	m.open_catalog()
	m.close_catalog({"kind": &"piece", "id": &"piece_wall"})
	assert_str(m.sub).is_equal(BuildModel.FASTEN)
	assert_str(m.selected["id"]).is_equal(&"piece_wall")
	m.end_fasten()
	assert_str(m.sub).is_equal(BuildModel.PREVIEW)


func test_removing_needs_full_hold() -> void:
	var m := BuildModel.new()
	for i in 35:
		assert_bool(m.tick_remove(1.0 / 60.0, true, true)).is_false()
	assert_str(m.sub).is_equal(BuildModel.REMOVING)
	assert_bool(m.tick_remove(1.0 / 60.0, true, true)).is_true()   # 36 frames = 0.6 s
	assert_str(m.sub).is_equal(BuildModel.PREVIEW)
	for i in 10:
		m.tick_remove(1.0 / 60.0, true, true)
	assert_bool(m.tick_remove(1.0 / 60.0, false, true)).is_false()   # released: back to preview, timer reset
	assert_float(m.remove_t).is_equal(0.0)
	assert_bool(m.tick_remove(1.0 / 60.0, true, false)).is_false()   # nothing to remove


func test_fasten_only_from_place_preview_and_rotation_wraps() -> void:
	var m := BuildModel.new()
	m.next_tool()
	assert_bool(m.begin_fasten()).is_false()
	m.next_tool(); m.next_tool()
	assert_bool(m.begin_fasten()).is_true()
	m.next_tool()   # changing tools leaves Fasten
	assert_str(m.sub).is_equal(BuildModel.PREVIEW)
	m.prev_tool()
	m.rotate(-1)
	assert_int(m.manual_rot).is_equal(3)


func test_rotate_means_region_in_paint_and_45_degrees_in_stamp() -> void:
	var m := BuildModel.new()
	m.next_tool()
	m.rotate(1)
	assert_int(m.paint_region).is_equal(1)
	assert_int(m.manual_rot).is_equal(0)
	m.next_tool()
	m.rotate(-1)
	assert_int(m.stamp_rot).is_equal(315)
