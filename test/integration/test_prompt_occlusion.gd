# P2.20 (completed in Phase 2B): prompts hide behind walls and terrain, show with line of sight.
extends GdUnitTestSuite

var h: Phase2Harness
var _tree: AppleTree


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start()
	_tree = AppleTree.new()
	_tree.name = "tree_o"
	h.add_scene_node(_tree, Vector3(0, 0, -3))
	h.place(Vector3(0, 0, 0))
	await h.frames(5)


func after_test() -> void:
	h.stop()
	await get_tree().process_frame


func _wall(pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var s := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	s.shape = box
	b.add_child(s)
	h.add_scene_node(b, pos)


func test_visible_with_clear_line_of_sight() -> void:
	var t := h.player.prompt_target()
	assert_bool(t.is_empty()).is_false()
	assert_bool(h.player.prompt_visible_from(Vector3(0, 3, 4), t)).is_true()


func test_hidden_behind_wall() -> void:
	_wall(Vector3(0, 1.5, 2), Vector3(4, 4, 0.3))
	await h.frames(2)
	var t := h.player.prompt_target()
	assert_bool(h.player.prompt_visible_from(Vector3(0, 3, 4), t)).is_false()


func test_hidden_behind_voxel_terrain() -> void:
	h.world.fill(Vector3i(-2, 0, 1), Vector3i(2, 4, 1), h.vid(&"mat_stone"))
	var t := h.player.prompt_target()
	assert_bool(h.player.prompt_visible_from(Vector3(0.5, 3, 4.5), t)).is_false()


func test_target_voxel_itself_does_not_hide_its_prompt() -> void:
	h.world.set_voxel(Vector3i(0, -1, 2), h.vid(&"mat_dirt"))
	_tree.queue_free()
	await h.frames(2)
	h.aim_at_cell(Vector3i(0, -1, 2))
	await h.frames(12)
	var t := h.player.prompt_target()
	assert_bool(t.is_empty()).is_false()
	assert_bool(h.player.prompt_visible_from(Vector3(0.5, 3, 4.5), t)).is_true()
