# P2.24: auto-tool rules 1 to 11 (spec 2.6), D15 keep-last-tool default.
extends GdUnitTestSuite

const DT := 1.0 / 60.0

var _belt: ToolBeltModel
var _m: ToolSelectionModel


func before_test() -> void:
	_belt = ToolBeltModel.new()
	for id in ["item_shovel_basic", "item_pickaxe_basic", "item_axe_basic", "item_picker_basic"]:
		_belt.grant(StringName(id))
	_m = ToolSelectionModel.new(_belt)


func _aim(tool: StringName, kind: StringName, tier := 0, blocked := &"", key := "voxel") -> Dictionary:
	return {"key": key, "tool": tool, "target_kind": kind, "tier_required": tier, "blocked": blocked}


func _zone(key: String, tool: StringName, priority: int, distance: float, inside := true, radius := 3.0) -> Dictionary:
	return {"key": key, "tool": tool, "target_kind": &"zone", "priority": priority, "distance": distance, "enter_radius": radius, "inside": inside, "active": true}


func _run(frames: int, aim: Dictionary, zones: Array = [], locked := false) -> Array:
	var all: Array = []
	for i in frames:
		all.append_array(_m.update(DT, aim, zones, locked))
	return all


func _equips(events: Array) -> Array:
	return events.filter(func(e): return e["type"] == &"equip")


func test_aim_equips_after_debounce() -> void:
	var ev := _run(8, _aim(ToolTypes.PICKAXE, &"voxel_hard"))
	assert_array(_equips(ev)).is_empty()
	ev = _run(2, _aim(ToolTypes.PICKAXE, &"voxel_hard"))
	assert_int(_equips(ev).size()).is_equal(1)
	assert_str(_equips(ev)[0]["reason"]).is_equal(&"aim_change")
	assert_str(_belt.equipped).is_equal(ToolTypes.PICKAXE)


func test_aim_beats_zone() -> void:
	_run(12, _aim(ToolTypes.SHOVEL, &"voxel_soft"), [_zone("tree", ToolTypes.FRUIT_PICKER, 20, 1.0)])
	assert_str(_belt.equipped).is_equal(ToolTypes.SHOVEL)


func test_zone_priority_then_distance_then_key() -> void:
	_run(12, {}, [_zone("a", ToolTypes.FRUIT_PICKER, 20, 1.0), _zone("b", ToolTypes.AXE, 30, 2.5)])
	assert_str(_belt.equipped).is_equal(ToolTypes.AXE)
	before_test()
	_run(12, {}, [_zone("a", ToolTypes.FRUIT_PICKER, 20, 2.0), _zone("b", ToolTypes.AXE, 20, 1.0)])
	assert_str(_belt.equipped).is_equal(ToolTypes.AXE)
	before_test()
	_run(12, {}, [_zone("b", ToolTypes.FRUIT_PICKER, 20, 1.0), _zone("a", ToolTypes.AXE, 20, 1.0)])
	assert_str(_belt.equipped).is_equal(ToolTypes.AXE)


func test_debounce_suppresses_flicker() -> void:
	var ev: Array = []
	for i in 6:
		ev.append_array(_run(4, _aim(ToolTypes.PICKAXE, &"voxel_hard")))
		ev.append_array(_run(4, _aim(ToolTypes.SHOVEL, &"voxel_soft")))
	assert_int(_equips(ev).size()).is_less_equal(1)


func test_zone_hysteresis() -> void:
	_run(12, {}, [_zone("t", ToolTypes.AXE, 20, 2.0)])
	assert_str(_belt.equipped).is_equal(ToolTypes.AXE)
	_belt.unequip()
	# Area reports exit but we are within radius + 0.5: still a candidate, re-equips.
	_run(12, {}, [_zone("t", ToolTypes.AXE, 20, 3.4, false)])
	assert_str(_belt.equipped).is_equal(ToolTypes.AXE)
	_belt.unequip()
	_run(12, {}, [_zone("t", ToolTypes.AXE, 20, 3.6, false)])
	assert_str(_belt.equipped).is_equal(ToolTypes.NONE)


func test_aim_grace_keeps_tool_briefly() -> void:
	_run(12, _aim(ToolTypes.PICKAXE, &"voxel_hard"))
	var ev := _run(10, {})   # 0.17 s without aim
	ev.append_array(_run(5, _aim(ToolTypes.PICKAXE, &"voxel_hard")))
	assert_array(_equips(ev)).is_empty()
	assert_str(_belt.equipped).is_equal(ToolTypes.PICKAXE)


func test_lock_defers_switch_then_lock_released() -> void:
	_run(12, _aim(ToolTypes.PICKAXE, &"voxel_hard"))
	var ev := _run(30, _aim(ToolTypes.SHOVEL, &"voxel_soft"), [], true)
	assert_array(_equips(ev)).is_empty()
	ev = _run(1, _aim(ToolTypes.SHOVEL, &"voxel_soft"))
	assert_int(_equips(ev).size()).is_equal(1)
	assert_str(_equips(ev)[0]["reason"]).is_equal(&"lock_released")


func test_manual_override_lasts_ten_seconds() -> void:
	assert_str(_m.manual_select(ToolTypes.AXE)["reason"]).is_equal(&"manual")
	_run(599, _aim(ToolTypes.PICKAXE, &"voxel_hard"))
	assert_str(_belt.equipped).is_equal(ToolTypes.AXE)
	_run(15, _aim(ToolTypes.PICKAXE, &"voxel_hard"))
	assert_str(_belt.equipped).is_equal(ToolTypes.PICKAXE)


func test_manual_override_ends_when_nothing_targeted() -> void:
	_m.manual_select(ToolTypes.AXE)
	_run(1, {})
	_run(30, {})
	_run(12, _aim(ToolTypes.PICKAXE, &"voxel_hard"))
	assert_str(_belt.equipped).is_equal(ToolTypes.PICKAXE)


func test_missing_tool_prompts_and_keeps_equipment() -> void:
	_belt.remove_type(ToolTypes.PICKAXE)
	var ev := _run(12, _aim(ToolTypes.PICKAXE, &"voxel_hard"))
	var prompts := ev.filter(func(e): return e["type"] == &"prompt")
	assert_int(prompts.size()).is_equal(1)
	assert_str(prompts[0]["state"]).is_equal(&"missing_tool")
	assert_str(_belt.equipped).is_equal(ToolTypes.NONE)


func test_tier_too_low_equips_with_badge() -> void:
	var ev := _run(12, _aim(ToolTypes.PICKAXE, &"voxel_hard", 3))
	assert_str(_belt.equipped).is_equal(ToolTypes.PICKAXE)
	assert_bool(ev.any(func(e): return e["type"] == &"prompt" and e["state"] == &"tier_lock")).is_true()


func test_blocked_voxel_gives_no_tool() -> void:
	var ev := _run(12, _aim(&"", &"voxel_soft", 0, &"protected"))
	assert_str(_belt.equipped).is_equal(ToolTypes.NONE)
	assert_bool(ev.any(func(e): return e["type"] == &"prompt" and e["state"] == &"protected")).is_true()


func test_keeps_last_tool_by_default_d15() -> void:
	_run(12, _aim(ToolTypes.PICKAXE, &"voxel_hard"))
	var ev := _run(120, {})
	assert_array(ev.filter(func(e): return e["type"] == &"unequip")).is_empty()
	assert_str(_belt.equipped).is_equal(ToolTypes.PICKAXE)


func test_revert_setting_unequips_after_one_second() -> void:
	_m.revert_when_idle = true
	_run(12, _aim(ToolTypes.PICKAXE, &"voxel_hard"))
	var ev := _run(18 + 59, {})   # 0.3 s aim grace, then 59 frames
	assert_array(ev.filter(func(e): return e["type"] == &"unequip")).is_empty()
	ev = _run(3, {})
	assert_int(ev.filter(func(e): return e["type"] == &"unequip").size()).is_equal(1)


func test_disabled_is_inert() -> void:
	_m.enabled = false
	assert_array(_run(30, _aim(ToolTypes.PICKAXE, &"voxel_hard"))).is_empty()
	assert_str(_belt.equipped).is_equal(ToolTypes.NONE)


func test_toolbelt_keeps_higher_tier() -> void:
	assert_bool(_belt.grant(&"item_pickaxe_copper")).is_true()
	assert_int(_belt.tool_data(ToolTypes.PICKAXE).tier).is_equal(2)
	assert_bool(_belt.grant(&"item_pickaxe_basic")).is_false()
	assert_int(_belt.tool_data(ToolTypes.PICKAXE).tier).is_equal(2)
	assert_bool(_belt.grant(&"item_apple")).is_false()
	var b2 := ToolBeltModel.new()
	b2.from_dict(_belt.to_dict())
	assert_dict(b2.to_dict()).is_equal(_belt.to_dict())
