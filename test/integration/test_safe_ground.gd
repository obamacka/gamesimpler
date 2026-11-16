# P2.32: kill plane returns to safe ground, bedrock, stuck hint.
extends GdUnitTestSuite

var h: Phase2Harness


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start()


func after_test() -> void:
	h.stop()
	await get_tree().process_frame


func test_kill_plane_returns_to_last_safe_position() -> void:
	h.place(Vector3(2, 0, 2))
	await h.frames(45)   # > 0.5 s standing: safe position recorded
	var safe := h.player.last_safe_position
	assert_float(safe.distance_to(Vector3(2, 0, 2))).is_less(0.2)
	var vol := SafetyVolume.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 2, 6)
	shape.shape = box
	vol.add_child(shape)
	h.add_scene_node(vol, Vector3(30, -20, 30))
	var returned := [0]
	EventBus.player_returned_to_safe_ground.connect(func(): returned[0] += 1)
	await h.frames(2)
	h.place(Vector3(30, -20, 30))
	var n := 0
	while returned[0] == 0 and n < 120:
		await get_tree().process_frame
		n += 1
	assert_int(returned[0]).is_equal(1)
	assert_float(h.player.global_position.distance_to(safe)).is_less(0.2)
	assert_bool(PauseManager.is_paused()).is_false()


func test_bedrock_cannot_be_dug() -> void:
	var bedrock := h.vid(&"mat_bedrock")
	h.world.set_voxel(Vector3i(0, -1, 3), bedrock)
	var r := h.session.terrain.hit_voxel(Vector3i(0, -1, 3), h.session.toolbelt.model.tool_data(ToolTypes.PICKAXE))
	assert_str(r["result"]).is_equal(TerrainRules.BEDROCK)
	assert_int(h.world.get_voxel(Vector3i(0, -1, 3))).is_equal(bedrock)


func test_below_zone_bounds_is_bedrock() -> void:
	h.world.set_voxel(Vector3i(0, -200, 0), h.vid(&"mat_stone"))
	assert_str(h.session.terrain.can_dig(Vector3i(0, -200, 0))).is_equal(TerrainRules.BEDROCK)


func test_stuck_detector() -> void:
	var s := StuckDetector.new()
	for i in 1199:
		assert_bool(s.update(1.0 / 60.0, true, Vector3.ZERO, true)).is_false()
	assert_bool(s.update(2.0 / 60.0, true, Vector3.ZERO, true)).is_true()
	assert_bool(s.update(1.0 / 60.0, true, Vector3.ZERO, true)).is_false()
	assert_bool(s.update(1.0 / 60.0, true, Vector3(1, 0, 0), true)).is_false()
	assert_bool(s.hinted).is_false()
