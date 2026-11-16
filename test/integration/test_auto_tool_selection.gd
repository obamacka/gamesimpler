# P2.29 / P3.19: Suite A (spec 8.3) cases A1 to A22. Ground voxels sit at y = -1 so their tops align with the physics floor.
extends GdUnitTestSuite

var h: Phase2Harness
var _rec: SignalRecorder
var _tree: AppleTree
var _timber: TimberTree


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start()
	for id in [&"item_axe_basic", &"item_hammer_basic", &"item_screwdriver_basic"]:
		h.session.toolbelt.model.grant(id)
	var w := h.world
	w.fill(Vector3i(-12, -1, -12), Vector3i(12, -1, 12), h.vid(&"mat_dirt"))
	w.fill(Vector3i(5, -1, -1), Vector3i(7, -1, 1), h.vid(&"mat_stone"))
	w.set_voxel(Vector3i(0, -1, -6), h.vid(&"mat_stone_hard"))
	h.session.terrain.rules.add_volume(Vector3i(-2, -2, 8), Vector3i(2, 2, 10), &"TOWN")
	_tree = AppleTree.new()
	_tree.name = "tree_a"
	h.add_scene_node(_tree, Vector3(-6, 0, 0))
	_timber = TimberTree.new()
	_timber.name = "timber_a"
	h.add_scene_node(_timber, Vector3(-6, 0, 6))
	_rec = SignalRecorder.new(EventBus, [&"tool_auto_selected", &"tool_unequipped", &"prompt_changed", &"tool_equipped"])
	h.place(Vector3(15, 0, 15))
	await h.frames(30)   # let the aim grace from spawn expire
	_rec.clear()


func after_test() -> void:
	_rec.stop()
	Engine.time_scale = 1.0
	h.stop()
	await get_tree().process_frame


func _selected() -> Array:
	return _rec.records.filter(func(r): return r["name"] == &"tool_auto_selected").map(func(r): return r["args"])


func _equipped() -> StringName:
	return h.session.toolbelt.model.equipped


func _at(pos: Vector3, cell = null) -> void:
	h.place(pos)
	if cell == null:
		h.aim_at_sky()
	else:
		h.aim_at_cell(cell)


func test_a1_aim_at_stone() -> void:
	_at(Vector3(3.5, 0, 0.5), Vector3i(5, -1, 0))
	await h.frames(12)
	assert_array(_selected()).contains_exactly([[ToolTypes.PICKAXE, &"voxel_hard", &"aim_change"]])
	assert_str(_equipped()).is_equal(ToolTypes.PICKAXE)


func test_a2_aim_at_dirt() -> void:
	_at(Vector3(0.5, 0, 0.5), Vector3i(0, -1, 2))
	await h.frames(12)
	assert_array(_selected()).contains_exactly([[ToolTypes.SHOVEL, &"voxel_soft", &"aim_change"]])


func test_a3_out_of_reach() -> void:
	_at(Vector3(-0.5, 0, 0.5), Vector3i(6, -1, 0))
	await h.frames(15)
	assert_array(_selected()).is_empty()


func test_a4_protected_voxel() -> void:
	_at(Vector3(0.5, 0, 7.0), Vector3i(0, -1, 9))
	await h.frames(12)
	assert_str(_equipped()).is_equal(ToolTypes.NONE)
	var prompts := _rec.records.filter(func(r): return r["name"] == &"prompt_changed")
	assert_bool(prompts.any(func(r): return r["args"][1] == TerrainRules.PROTECTED)).is_true()


func test_a5_fruit_tree_zone() -> void:
	_at(Vector3(-4.2, 0, 0))
	await h.frames(15)
	assert_array(_selected()).contains_exactly([[ToolTypes.FRUIT_PICKER, &"fruit_tree", &"zone_enter"]])


func test_a6_tree_without_fruit() -> void:
	h.session.world_state.fruit[_tree.key]["fruit"] = 0
	_at(Vector3(-4.2, 0, 0))
	await h.frames(15)
	assert_array(_selected()).is_empty()


func test_a7_timber_zone() -> void:
	_at(Vector3(-4.6, 0, 6))
	await h.frames(15)
	assert_array(_selected()).contains_exactly([[ToolTypes.AXE, &"timber", &"zone_enter"]])


func test_a11_aim_beats_zone() -> void:
	_at(Vector3(-4.2, 0, 0.5), Vector3i(-4, -1, 2))
	await h.frames(15)
	assert_str(_equipped()).is_equal(ToolTypes.SHOVEL)


func test_a12_nearer_zone_wins_on_equal_priority() -> void:
	var t2 := TimberTree.new()
	t2.name = "timber_b"
	h.add_scene_node(t2, Vector3(-6, 0, 2.5))
	_at(Vector3(-5.0, 0, 0.4))
	await h.frames(15)
	assert_str(_equipped()).is_equal(ToolTypes.FRUIT_PICKER)
	_at(Vector3(-5.0, 0, 2.2))
	await h.frames(15)
	assert_str(_equipped()).is_equal(ToolTypes.AXE)


func test_a13_keeps_tool_then_revert_setting() -> void:
	_at(Vector3(3.5, 0, 0.5), Vector3i(5, -1, 0))
	await h.frames(12)
	_at(Vector3(15, 0, 15))
	await h.frames(120)
	assert_str(_equipped()).is_equal(ToolTypes.PICKAXE)
	assert_int(_rec.count(&"tool_unequipped")).is_equal(0)
	Settings.model.set_value("assist", "auto_tool_revert", true)
	_at(Vector3(3.5, 0, 0.5), Vector3i(5, -1, 0))
	await h.frames(3)
	_at(Vector3(15, 0, 15))
	await h.frames(18 + 56)   # aim grace 0.3 s, then under 1.0 s
	assert_int(_rec.count(&"tool_unequipped")).is_equal(0)
	await h.frames(8)
	assert_int(_rec.count(&"tool_unequipped")).is_equal(1)


func test_a14_debounce() -> void:
	h.place(Vector3(3.5, 0, 0.5))
	for i in 3:
		h.aim_at_cell(Vector3i(5, -1, 0))
		await h.frames(4)
		h.aim_at_cell(Vector3i(3, -1, 2))
		await h.frames(4)
	assert_int(_selected().size()).is_less_equal(1)


func test_a15_voxel_aim_hysteresis() -> void:
	_at(Vector3(3.5, 0, 0.5), Vector3i(5, -1, 0))
	await h.frames(12)
	_rec.clear()
	h.aim_at_sky()
	await h.frames(10)
	h.aim_at_cell(Vector3i(5, -1, 0))
	await h.frames(10)
	assert_array(_selected()).is_empty()
	assert_int(_rec.count(&"tool_unequipped")).is_equal(0)


func test_a16_action_lock_then_lock_released() -> void:
	_at(Vector3(3.5, 0, 0.5), Vector3i(5, -1, 0))
	await h.frames(12)
	_rec.clear()
	h.press("use_pressed", {"use_held": true})
	h.hold({"use_held": true})
	await h.frames(3)
	assert_str(h.player.machine.current_id).is_equal(&"mine")
	h.aim_at_cell(Vector3i(3, -1, 2))   # dirt
	await h.frames(10)
	assert_array(_selected()).is_empty()
	h.hold({})
	var n := 0
	while h.player.machine.current_id == &"mine" and n < 120:
		await h.frames(1)
		n += 1
	await h.frames(3)
	assert_array(_selected()).contains_exactly([[ToolTypes.SHOVEL, &"voxel_soft", &"lock_released"]])


func test_a17_airborne_does_not_lock() -> void:
	_at(Vector3(3.5, 0, 0.5), Vector3i(5, -1, 0))
	await h.frames(12)
	_rec.clear()
	h.press("jump_pressed")
	await h.frames(2)
	h.aim_at_cell(Vector3i(3, -1, 2))
	await h.frames(12)
	assert_bool(h.player.current_state().is_airborne()).is_true()
	assert_str(_equipped()).is_equal(ToolTypes.SHOVEL)


func test_a18_manual_override() -> void:
	h.place(Vector3(3.5, 0, 0.5))
	h.aim_at_cell(Vector3i(5, -1, 0))
	await h.frames(2)
	assert_bool(h.player.tool_selector.manual_select(ToolTypes.AXE)).is_true()
	Engine.time_scale = 4.0
	await h.frames(145)   # about 9.7 game seconds
	assert_str(_equipped()).is_equal(ToolTypes.AXE)
	await h.frames(12)
	Engine.time_scale = 1.0
	assert_str(_equipped()).is_equal(ToolTypes.PICKAXE)


func test_a19_missing_tool() -> void:
	h.session.toolbelt.model.remove_type(ToolTypes.PICKAXE)
	_at(Vector3(3.5, 0, 0.5), Vector3i(5, -1, 0))
	await h.frames(12)
	assert_str(_equipped()).is_equal(ToolTypes.NONE)
	var prompts := _rec.records.filter(func(r): return r["name"] == &"prompt_changed")
	assert_bool(prompts.any(func(r): return r["args"][1] == &"missing_tool" and r["args"][2] == ToolTypes.PICKAXE)).is_true()


func test_a20_tier_too_low() -> void:
	_at(Vector3(0.5, 0, -3.8), Vector3i(0, -1, -6))
	await h.frames(12)
	assert_str(_equipped()).is_equal(ToolTypes.PICKAXE)
	var prompts := _rec.records.filter(func(r): return r["name"] == &"prompt_changed")
	assert_bool(prompts.any(func(r): return r["args"][1] == &"tier_lock")).is_true()
	var stamina := h.session.stamina.model.current
	h.press("use_pressed", {"use_held": true})
	await h.frames(40)
	assert_int(h.session.stamina.model.current).is_equal(stamina)
	assert_int(h.world.get_voxel(Vector3i(0, -1, -6))).is_equal(h.vid(&"mat_stone_hard"))


func test_a21_setting_off() -> void:
	Settings.model.set_value("assist", "auto_tool", false)
	_at(Vector3(3.5, 0, 0.5), Vector3i(5, -1, 0))
	await h.frames(15)
	assert_array(_selected()).is_empty()


func test_a22_paused() -> void:
	PauseManager.request_pause(&"menu")
	_at(Vector3(3.5, 0, 0.5), Vector3i(5, -1, 0))
	await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	assert_array(_selected()).is_empty()
	PauseManager.release_pause(&"menu")
	await h.frames(12)
	assert_int(_selected().size()).is_equal(1)


# ---- P3.19: A8 to A10, loose build pieces. A test plot in the wilderness holds a LOOSE
# nailed wall at (3,0,6) and a LOOSE screwed shelf at (5,0,6).
var _plot: PlotDef


func _build_fixture() -> void:
	_plot = PlotDef.new()
	_plot.id = &"plot_suite_a"
	_plot.zone_id = &"zone_wilderness"
	_plot.min_cell = Vector3i(0, -2, 3)
	_plot.max_cell = Vector3i(8, 10, 8)
	Database.plots[_plot.id] = _plot
	h.session.housing.grant_deed(_plot.id)
	h.session.inventory.add(&"item_piece_wall", 1)
	h.session.inventory.add(&"item_piece_shelf", 1)
	assert_bool(h.session.build.try_place(&"piece_wall", Vector3i(3, 0, 6), 0).ok).is_true()
	assert_bool(h.session.build.try_place(&"piece_shelf", Vector3i(5, 0, 6), 0).ok).is_true()
	await h.frames(2)


func _drop_fixture() -> void:
	Database.plots.erase(&"plot_suite_a")


func test_a8_hammer_in_build() -> void:
	await _build_fixture()
	_at(Vector3(3.5, 0, 4.5))
	await h.frames(4)
	_rec.clear()
	h.press("build_toggle_pressed")
	await h.frames(16)
	assert_str(h.player.machine.current_id).is_equal(&"build")
	assert_array(_selected()).contains_exactly([[ToolTypes.HAMMER, &"loose_piece", &"zone_enter"]])
	_drop_fixture()


func test_a9_screwdriver_by_fastener() -> void:
	await _build_fixture()
	_at(Vector3(6.5, 0, 4.5))
	await h.frames(4)
	h.press("build_toggle_pressed")
	await h.frames(16)
	assert_str(_equipped()).is_equal(ToolTypes.SCREWDRIVER)
	assert_array(_selected().back()).contains_exactly([ToolTypes.SCREWDRIVER, &"loose_piece", &"zone_enter"])
	_drop_fixture()


func test_a10_loose_piece_zones_ignored_outside_build() -> void:
	await _build_fixture()
	_at(Vector3(3.5, 0, 4.5))
	await h.frames(40)
	assert_array(_selected().filter(func(a): return a[0] == ToolTypes.HAMMER)).is_empty()
	h.press("build_toggle_pressed")
	await h.frames(16)
	h.press("build_toggle_pressed")   # exit Build, stay near the wall
	await h.frames(4)
	assert_str(h.player.machine.current_id).is_not_equal(&"build")
	h.session.toolbelt.model.equip(ToolTypes.SHOVEL)
	_rec.clear()
	await h.frames(40)
	assert_array(_selected().filter(func(a): return a[0] == ToolTypes.HAMMER)).is_empty()
	_drop_fixture()
