# P2B.15: Suite F (spec 8.5.1). Fixture: zone_home_meadow with the starter garden plot
# (x 4..11, z -4..3) of grass on dirt at y -1, a protection volume at x 13..15, a well at
# (-4.5, 0, 8.5). Inventory: 5 carrot seeds (hotbar 0), 2 strawberry seeds (hotbar 1),
# 1 sprinkler (hotbar 2). Day 3, 08:00. F15's discovery assertion waits for Phase 6.
extends GdUnitTestSuite

const Z := &"zone_home_meadow"
const SIGNALS: Array[StringName] = [&"soil_tilled", &"crop_planted", &"crop_watered", &"crop_grew",
	&"crop_harvested", &"can_refilled", &"tool_auto_selected", &"stamina_depleted", &"player_woke",
	&"sleep_transition_started"]
const SOIL := Vector3i(5, -1, 0)
const CROP := Vector3i(5, 0, 0)
const STAND := Vector3(5.5, 0, 2.5)   # two cells south of SOIL

var h: Phase2Harness
var _rec: SignalRecorder


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(Z, &"spawn_start")
	GameClock.model.set_time(3, 8 * 60)
	h.world.fill(Vector3i(-8, -3, -8), Vector3i(18, -2, 12), h.vid(&"mat_dirt"))
	h.world.fill(Vector3i(-8, -1, -8), Vector3i(18, -1, 12), h.vid(&"mat_grass"))
	h.session.inventory.add(&"item_seed_carrot", 5)
	h.session.inventory.add(&"item_seed_strawberry", 2)
	h.session.inventory.add(&"item_sprinkler", 1)
	_rec = SignalRecorder.new(EventBus, SIGNALS)


func after_test() -> void:
	_rec.stop()
	h.stop()
	await get_tree().process_frame


func _farm() -> FarmService:
	return h.session.farm


func _crop(cell: Vector3i = CROP) -> Dictionary:
	return _farm().model.crop_at(Z, cell)


func _select(slot: int) -> void:
	h.press("hotbar_next_pressed", {"hotbar_select": slot})
	await h.frames(2)


func _aim_from(stand: Vector3, cell: Vector3i) -> void:
	h.place(stand)
	await h.frames(2)
	h.aim_at_cell(cell)
	await h.frames(14)   # past the auto-tool debounce


func _wait_idle(max_frames: int = 180) -> void:
	var n := 0
	await h.frames(2)
	while h.player.machine.current_id != &"idle" and n < max_frames:
		await h.frames(1)
		n += 1


func _use() -> void:
	h.press("use_pressed", {"use_held": true})
	await _wait_idle()


func _ripen(cell: Vector3i = CROP) -> void:
	var c := _crop(cell)
	c["growth_days"] = (Database.crops[StringName(c["crop_id"])] as CropDef).days_to_ripe()


func _await_woke(timeout_frames: int = 900) -> void:
	var n := 0
	while _rec.count(&"player_woke") == 0 and n < timeout_frames:
		await get_tree().process_frame
		n += 1
	await h.frames(2)


func test_f1_till_and_plant() -> void:
	var stamina := h.session.stamina.model.current
	await _select(0)
	await _aim_from(STAND, SOIL)
	await _use()
	var order := _rec.names().filter(func(n): return n in [&"soil_tilled", &"crop_planted"])
	assert_array(order).contains_exactly([&"soil_tilled", &"crop_planted"])
	assert_int(h.world.get_voxel(SOIL)).is_equal(h.vid(&"mat_farmland"))
	assert_int(h.session.inventory.count(&"item_seed_carrot")).is_equal(4)
	assert_int(h.session.stamina.model.current).is_equal(stamina - 1)
	assert_str(_crop()["crop_id"]).is_equal("crop_carrot")
	assert_str(h.session.toolbelt.model.equipped).is_equal(ToolTypes.HOE)


func test_f2_till_refused_outside_farmable_area() -> void:
	var stamina := h.session.stamina.model.current
	var outside := Vector3i(5, -1, 6)
	var protected := Vector3i(13, -1, 0)
	assert_str(_farm().try_till(outside, &"item_seed_carrot").error).is_equal(FarmModel.NOT_FARMABLE)
	assert_str(_farm().try_till(protected, &"item_seed_carrot").error).is_equal(FarmModel.PROTECTED)
	await _select(0)
	await _aim_from(Vector3(5.5, 0, 8.5), outside)
	assert_str(h.player.tool_selector.last_aim["blocked"]).is_equal(FarmModel.NOT_FARMABLE)
	await _use()
	await _aim_from(Vector3(13.5, 0, 2.5), protected)
	assert_str(h.player.tool_selector.last_aim["blocked"]).is_equal(TerrainRules.PROTECTED)
	await _use()
	assert_int(_rec.count(&"soil_tilled")).is_equal(0)
	assert_int(h.session.inventory.count(&"item_seed_carrot")).is_equal(5)
	assert_int(h.session.stamina.model.current).is_equal(stamina)
	assert_int(h.world.get_voxel(outside)).is_equal(h.vid(&"mat_grass"))


func test_f3_no_seed_selected_digs() -> void:
	await _select(5)   # empty hotbar slot
	await _aim_from(STAND, SOIL)
	assert_str(h.session.toolbelt.model.equipped).is_equal(ToolTypes.SHOVEL)
	h.press("use_pressed", {"use_held": true})
	h.hold({"use_held": true})
	var n := 0
	while h.world.get_voxel(SOIL) != IVoxelWorld.AIR and n < 400:
		await h.frames(1)
		n += 1
	h.hold({})
	assert_int(h.world.get_voxel(SOIL)).is_equal(IVoxelWorld.AIR)
	assert_int(_rec.count(&"soil_tilled")).is_equal(0)


func test_f4_water() -> void:
	_farm().try_till(SOIL, &"item_seed_carrot")
	await _select(5)
	await _aim_from(STAND, SOIL)
	assert_str(h.player.tool_selector.last_aim["target_kind"]).is_equal(&"water")
	await _use()
	assert_int(_rec.count(&"crop_watered")).is_equal(1)
	assert_int(_farm().model.can_water).is_equal(19)
	await _use()   # already watered today: no action, no water
	assert_int(_rec.count(&"crop_watered")).is_equal(1)
	assert_str(_farm().try_water(CROP).error).is_equal(FarmModel.ALREADY)
	assert_int(_farm().model.can_water).is_equal(19)


func test_f5_growth_at_rollover() -> void:
	_farm().try_till(SOIL, &"item_seed_carrot")
	_farm().try_water(SOIL)
	h.session.rollover.run(4)
	assert_int(_crop()["growth_days"]).is_equal(1)
	var grew := _rec.records.filter(func(r): return r["name"] == &"crop_grew")
	assert_int(grew.size()).is_equal(1)
	assert_array(grew[0]["args"]).contains_exactly([CROP, 1])


func test_f6_unwatered_does_not_grow_and_never_dies() -> void:
	_farm().try_till(SOIL, &"item_seed_carrot")
	for day in range(4, 9):
		h.session.rollover.run(day)
	assert_bool(_crop().is_empty()).is_false()
	assert_int(_crop()["growth_days"]).is_equal(0)
	assert_int(_rec.count(&"crop_grew")).is_equal(0)


func test_f7_harvest_ripe_crop() -> void:
	_farm().try_till(SOIL, &"item_seed_carrot")
	_ripen()
	var def: CropDef = Database.crops[&"crop_carrot"]
	var shadow := FarmModel.new()   # same rules and RNG state predict the roll
	shadow.mark_tilled(Z, SOIL)
	shadow.plant(Z, SOIL, &"crop_carrot", 3)
	shadow.crops[FarmModel.key(Z, CROP)]["growth_days"] = def.days_to_ripe()
	var rng := RngStreams.new(h.session.rng.seed_value)
	rng.from_dict(h.session.rng.to_dict())
	var expected := shadow.harvest(Z, CROP, def, rng)
	await _select(5)
	await _aim_from(STAND, SOIL)
	assert_object(h.player.prompt_target()["primary"]).is_not_null()
	assert_str(h.player.prompt_target()["primary"].kind).is_equal(&"HARVEST")
	h.press("interact_pressed")
	await _wait_idle()
	var hv := _rec.records.filter(func(r): return r["name"] == &"crop_harvested")
	assert_int(hv.size()).is_equal(1)
	assert_array(hv[0]["args"]).contains_exactly([CROP, &"crop_carrot", expected["qty"]])
	assert_int(h.session.inventory.count(&"item_carrot")).is_equal(expected["qty"])
	assert_int(h.session.inventory.count(&"item_seed_carrot")).is_equal(4 + expected["seeds"])
	assert_bool(_crop().is_empty()).is_true()
	assert_bool(_farm().model.is_tilled(Z, SOIL)).is_true()
	assert_int(h.world.get_voxel(SOIL)).is_equal(h.vid(&"mat_farmland"))


func test_f8_regrow_crop() -> void:
	_farm().try_till(SOIL, &"item_seed_strawberry")
	_ripen()
	var def: CropDef = Database.crops[&"crop_strawberry"]
	assert_bool(_farm().try_harvest(CROP).ok).is_true()
	assert_int(def.stage_for(_crop()["growth_days"])).is_equal(def.regrow_stage)
	assert_int(_crop()["harvests"]).is_equal(1)
	assert_str(h.session.terrain.can_dig(SOIL)).is_equal(TerrainRules.SUPPORTS_OBJECT)


func test_f9_refill() -> void:
	_farm().model.can_water = 0
	h.place(Vector3(-4.5, 0, 11.5))
	await h.frames(2)
	var eye := h.player.global_position + Vector3(0, 1.95, 0)
	h.player.tool_selector.set_aim_for_tests(eye, Vector3(-4.5, 1.2, 8.5) - eye)
	await h.frames(14)
	assert_str(h.player.tool_selector.best()["target_kind"]).is_equal(&"refill")
	var auto := _rec.records.filter(func(r): return r["name"] == &"tool_auto_selected")
	assert_array(auto.back()["args"].slice(0, 2)).contains_exactly([ToolTypes.WATERING_CAN, &"refill"])
	await _use()
	assert_int(_farm().model.can_water).is_equal(20)
	assert_int(_rec.count(&"can_refilled")).is_equal(1)


func test_f10_sprinkler() -> void:
	h.session.inventory.add(&"item_seed_carrot", 5)
	var center := Vector3i(7, 0, 0)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx != 0 or dz != 0:
				assert_bool(_farm().try_till(center + Vector3i(dx, -1, dz), &"item_seed_carrot").ok).is_true()
	var r := _farm().try_place_sprinkler(center)
	assert_bool(r.ok).override_failure_message(str(r.error)).is_true()
	assert_int(h.session.inventory.count(&"item_sprinkler")).is_equal(0)
	assert_str(h.session.terrain.rules.can_place(center)).is_equal(TerrainRules.OCCUPIED)
	h.session.rollover.run(4)
	assert_int(_rec.count(&"crop_grew")).is_equal(8)


func test_f11_unloaded_zone_grows() -> void:
	_farm().try_till(SOIL, &"item_seed_carrot")
	_farm().try_water(SOIL)
	await SceneRouter.travel(&"zone_wilderness", &"spawn_start")
	h.session.rollover.run(4)
	await SceneRouter.travel(Z, &"spawn_start")
	assert_int(_crop()["growth_days"]).is_equal(1)
	var view: FarmView = SceneRouter.current_zone.get_node("FarmView")
	assert_int(view.stage_of(FarmModel.key(Z, CROP))).is_equal(1)
	assert_str(h.session.terrain.can_dig(SOIL)).is_equal(TerrainRules.SUPPORTS_OBJECT)   # protection re-registered


func test_f12_protection_while_planted() -> void:
	_farm().try_till(SOIL, &"item_seed_carrot")
	var shovel := h.session.toolbelt.model.tool_data(ToolTypes.SHOVEL)
	assert_str(h.session.terrain.hit_voxel(SOIL, shovel)["result"]).is_equal(TerrainRules.SUPPORTS_OBJECT)
	assert_str(h.session.terrain.rules.can_place(CROP)).is_equal(TerrainRules.OCCUPIED)
	_ripen()
	_farm().try_harvest(CROP)   # single harvest frees the cells
	assert_str(h.session.terrain.rules.can_place(CROP)).is_equal(TerrainRules.OK)
	assert_str(h.session.terrain.can_dig(SOIL)).is_equal(TerrainRules.OK)


func test_f13_auto_tool_farm_rules() -> void:
	await _select(0)
	await _aim_from(STAND, SOIL)
	assert_str(h.session.toolbelt.model.equipped).is_equal(ToolTypes.HOE)
	_farm().try_till(Vector3i(6, -1, 0))
	await _select(5)
	await _aim_from(Vector3(6.5, 0, 2.5), Vector3i(6, -1, 0))
	assert_str(h.session.toolbelt.model.equipped).is_equal(ToolTypes.WATERING_CAN)
	_farm().try_till(Vector3i(7, -1, 0), &"item_seed_carrot")
	_ripen(Vector3i(7, 0, 0))
	h.session.toolbelt.model.equip(ToolTypes.SHOVEL)
	await _aim_from(Vector3(7.5, 0, 2.5), Vector3i(7, -1, 0))
	assert_str(h.session.toolbelt.model.equipped).is_equal(ToolTypes.SHOVEL)   # no tool change for harvest
	assert_str(h.player.prompt_target()["primary"].kind).is_equal(&"HARVEST")
	h.place(Vector3(-4.5, 0, 11.5))
	await h.frames(2)
	var eye := h.player.global_position + Vector3(0, 1.95, 0)
	h.player.tool_selector.set_aim_for_tests(eye, Vector3(-4.5, 1.2, 8.5) - eye)
	await h.frames(14)
	assert_str(h.session.toolbelt.model.equipped).is_equal(ToolTypes.WATERING_CAN)
	assert_str(h.player.tool_selector.best()["target_kind"]).is_equal(&"refill")


func test_f14_exhaustion_while_farming() -> void:
	var watered := Vector3i(8, -1, 0)
	_farm().try_till(watered, &"item_seed_carrot")
	_farm().try_water(watered)
	h.session.stamina.model.current = 1
	await _select(0)
	await _aim_from(STAND, SOIL)
	h.press("use_pressed", {"use_held": true})
	await _await_woke()
	assert_int(_rec.count(&"soil_tilled")).is_equal(2)
	assert_int(_rec.count(&"crop_planted")).is_equal(2)
	assert_int(_rec.count(&"stamina_depleted")).is_equal(1)
	assert_int(_rec.count(&"sleep_transition_started")).is_equal(1)
	assert_int(GameClock.model.day).is_equal(4)
	assert_int(_crop(watered + Vector3i.UP)["growth_days"]).is_equal(1)
	assert_int(_crop()["growth_days"]).is_equal(0)


func test_f15_harvested_produce_is_a_collection_entry() -> void:
	# Phase 6 (CollectionService) adds: entry_discovered(&"item_carrot") once on a fresh session.
	_farm().try_till(SOIL, &"item_seed_carrot")
	_ripen()
	assert_bool(_farm().try_harvest(CROP).ok).is_true()
	var it := Database.item(&"item_carrot")
	assert_str(it.category).is_equal(&"PRODUCE")
	assert_int(h.session.inventory.count(&"item_carrot")).is_greater(0)


func test_f16_serialization() -> void:
	_farm().try_till(SOIL, &"item_seed_carrot")
	_farm().try_water(SOIL)
	_farm().try_till(Vector3i(6, -1, 0))
	var d := _farm().to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify({"farm": d}))
	var other := FarmService.new()
	other.from_dict(parsed["farm"])
	assert_dict(other.to_dict()).is_equal(d)
	var c: Dictionary = other.model.crops[FarmModel.key(Z, CROP)]
	for k in ["growth_days", "planted_day", "harvests"]:
		assert_int(typeof(c[k])).is_equal(TYPE_INT)
	assert_int(typeof(other.model.can_water)).is_equal(TYPE_INT)
	other.free()
