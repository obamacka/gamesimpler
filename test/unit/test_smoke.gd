# Phase 0 smoke suite: proves the headless gdUnit4 runner discovers and passes tests.
extends GdUnitTestSuite


func test_engine_version_is_4_7() -> void:
	var info := Engine.get_version_info()
	assert_int(info["major"]).is_equal(4)
	assert_int(info["minor"]).is_equal(7)


func test_physics_engine_is_jolt() -> void:
	assert_str(ProjectSettings.get_setting("physics/3d/physics_engine")).is_equal("Jolt Physics")


func test_rendering_method_is_forward_plus() -> void:
	assert_str(ProjectSettings.get_setting("rendering/renderer/rendering_method")).is_equal("forward_plus")


func test_physics_layer_names_match_spec() -> void:
	var expected := ["world", "player", "npc", "pet", "interactables", "tool_zones", "build_pieces", "pickups", "safety"]
	for i in expected.size():
		var key := "layer_names/3d_physics/layer_%d" % (i + 1)
		assert_str(ProjectSettings.get_setting(key)).is_equal(expected[i])
