# P6.14: Suite C (spec 8.5) C1 to C17. Uses the real museum zone (STATIC) and content:
# case_minerals (COUNT 2), trophy_first_donation (TOTAL_COUNT 1, +10 max stamina, 50 coins).
# The non-collectible stand-in for item_plank_pine is item_wood.
extends GdUnitTestSuite

const DIR := "user://test_tmp/suite_c"
const SIGNALS: Array[StringName] = [&"item_donated", &"trophy_unlocked", &"display_case_unlocked", &"entry_discovered"]

var h: Phase2Harness
var _rec: SignalRecorder


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_museum", &"spawn_start")
	SaveService.base_dir = DIR
	VoxelPersistence.remove_dir(DIR)
	_rec = SignalRecorder.new(EventBus, SIGNALS)


func after_test() -> void:
	_rec.stop()
	VoxelPersistence.remove_dir(DIR)
	h.stop()
	await get_tree().process_frame


func _m() -> MuseumService:
	return h.session.museum


func _reward_letters() -> Array:
	var all: Array = h.session.mail.model.scheduled + h.session.mail.model.inbox
	return all.filter(func(m): return m["template_id"] == "mail_tpl_museum_reward")


func test_c1_first_donation() -> void:
	h.session.inventory.add(&"item_quartz", 2)
	var bonus := h.session.stamina.model.bonus
	var r := _m().try_donate(&"item_quartz")
	assert_bool(r.ok).is_true()
	assert_int(h.session.inventory.count(&"item_quartz")).is_equal(1)
	var don := _rec.records.filter(func(x): return x["name"] == &"item_donated")
	assert_int(don.size()).is_equal(1)
	assert_array(don[0]["args"]).contains_exactly([&"item_quartz", &"MINERAL"])
	assert_bool(_m().model.is_donated(&"item_quartz")).is_true()
	assert_int(_rec.count(&"trophy_unlocked")).is_equal(1)
	assert_int(h.session.stamina.model.bonus).is_equal(bonus + 10)
	assert_int(_reward_letters().size()).is_equal(1)


func test_c2_duplicate_guard() -> void:
	h.session.inventory.add(&"item_quartz", 2)
	_m().try_donate(&"item_quartz")
	_rec.clear()
	assert_str(_m().try_donate(&"item_quartz").error).is_equal(MuseumModel.ALREADY)
	assert_int(h.session.inventory.count(&"item_quartz")).is_equal(1)
	assert_int(_rec.count(&"item_donated")).is_equal(0)
	assert_int(_m().model.donated.size()).is_equal(1)


func test_c3_same_frame_double_call() -> void:
	h.session.inventory.add(&"item_agate", 3)
	var a := _m().try_donate(&"item_agate")
	var b := _m().try_donate(&"item_agate")
	assert_bool(a.ok).is_true()
	assert_str(b.error).is_equal(MuseumModel.ALREADY)
	assert_int(h.session.inventory.count(&"item_agate")).is_equal(2)


func test_c4_batch_with_duplicates() -> void:
	h.session.inventory.add(&"item_amethyst", 2)
	h.session.inventory.add(&"item_apple", 1)
	var res := _m().try_donate_batch([&"item_amethyst", &"item_amethyst", &"item_apple"])
	assert_int(res.size()).is_equal(2)
	assert_bool(res.all(func(x): return x["ok"])).is_true()
	assert_int(res.filter(func(x): return x["item_id"] == &"item_amethyst").size()).is_equal(1)
	assert_int(h.session.inventory.count(&"item_amethyst")).is_equal(1)


func test_c5_instance_data_ignored() -> void:
	h.session.inventory.add(&"item_cotton_cloth", 1, {"dye": "dye_moss"})
	assert_bool(_m().try_donate(&"item_cotton_cloth").ok).is_true()
	h.session.inventory.add(&"item_cotton_cloth", 1)
	assert_str(_m().try_donate(&"item_cotton_cloth").error).is_equal(MuseumModel.ALREADY)


func test_c6_prefer_plain_stack() -> void:
	h.session.inventory.add(&"item_cotton_cloth", 1, {"dye": "dye_moss"})
	h.session.inventory.add(&"item_cotton_cloth", 1)
	_m().try_donate(&"item_cotton_cloth")
	var left: Array = h.session.inventory.model.slots.filter(func(s): return s != null and s["item_id"] == &"item_cotton_cloth")
	assert_int(left.size()).is_equal(1)
	assert_dict(left[0]["data"]).is_equal({"dye": "dye_moss"})


func test_c7_not_collectible_c8_not_owned() -> void:
	h.session.inventory.add(&"item_wood", 1)
	var before := h.session.inventory.model.to_dict()
	assert_str(_m().try_donate(&"item_wood").error).is_equal(MuseumModel.NOT_COLLECTIBLE)
	assert_str(_m().try_donate(&"item_topaz").error).is_equal(MuseumModel.NOT_IN_INVENTORY)
	assert_dict(h.session.inventory.model.to_dict()).is_equal(before)
	assert_int(_rec.count(&"item_donated")).is_equal(0)


func test_c9_case_unlock_once_and_displays() -> void:
	h.session.inventory.add(&"item_quartz", 1)
	h.session.inventory.add(&"item_amethyst", 1)
	_m().try_donate(&"item_quartz")
	_m().try_donate(&"item_amethyst")
	h.session.inventory.add(&"item_agate", 1)
	_m().try_donate(&"item_agate")
	assert_int(_rec.records.filter(func(x): return x["name"] == &"display_case_unlocked" and x["args"][0] == &"case_minerals").size()).is_equal(1)
	await h.frames(2)
	var case_node: DisplayCase = SceneRouter.current_zone.get_node("CaseMinerals")
	assert_int(case_node.display_count()).is_equal(3)


func test_c10_c11_round_trip_silent_load() -> void:
	h.session.inventory.add(&"item_quartz", 1)
	h.session.inventory.add(&"item_apple", 1)
	_m().try_donate(&"item_quartz")
	var before := _m().model.to_dict()
	var coll := h.session.collection.model.to_dict()
	var letters := _reward_letters().size()
	_rec.clear()
	assert_bool((await SaveService.save_slot(1, h.session)).ok).is_true()
	var r := SaveService.load_slot(1)
	h.session.from_dict(r.data["data"])
	assert_dict(_m().model.to_dict()).is_equal(before)
	assert_dict(h.session.collection.model.to_dict()).is_equal(coll)
	for k in _m().model.donated:
		assert_int(typeof(_m().model.donated[k])).is_equal(TYPE_INT)
	for sig in [&"item_donated", &"trophy_unlocked", &"display_case_unlocked"]:
		assert_int(_rec.count(sig)).override_failure_message("load emitted %s" % sig).is_equal(0)
	assert_int(_reward_letters().size()).is_equal(letters)


func test_c12_sanitization() -> void:
	h.session.inventory.add(&"item_quartz", 1)
	_m().try_donate(&"item_quartz")
	var d: Dictionary = JSON.parse_string(SaveCodec.encode(h.session.to_dict()))
	d["collection"]["discovered"] = ["item_apple", "item_apple", "item_removed_thing"]
	d["museum"]["donated"]["item_removed_thing"] = 3
	var r := SaveCodec.decode(JSON.stringify(d))
	assert_bool(r["ok"]).is_true()
	h.session.from_dict(r["data"])
	assert_array(h.session.collection.model.to_dict()["discovered"]).is_equal(["item_apple", "item_quartz"])
	assert_bool(_m().model.donated.has("item_removed_thing")).is_false()


func test_c13_structural_failure_falls_back_to_bak() -> void:
	h.session.inventory.add(&"item_quartz", 1)
	_m().try_donate(&"item_quartz")
	await SaveService.save_slot(1, h.session)
	await SaveService.save_slot(1, h.session)   # primary and .bak both valid
	var p := SaveService.paths(1)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(p["json"]))
	d["museum"]["donated"] = ["item_quartz"]
	var f := FileAccess.open(p["json"], FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var r := SaveService.load_slot(1)
	assert_bool(r.ok).is_true()
	assert_str(r.data["used"]).is_equal("bak")
	assert_array(r.data["notices"]).contains([&"backup_used"])


func test_c14_reconcile_new_content_once() -> void:
	var d: Dictionary = JSON.parse_string(SaveCodec.encode(h.session.to_dict()))
	# a save made before trophy_crop_set existed: every crop donated, no trophy recorded
	for id in ["item_carrot", "item_sunflower", "item_pumpkin", "item_cotton", "item_strawberry", "item_tomato"]:
		d["museum"]["donated"][id] = 2
	d["museum"]["trophies_unlocked"] = ["trophy_first_donation"]
	d["museum"]["rewards_granted"] = ["trophy_first_donation"]
	d["museum"]["cases_unlocked"] = ["case_produce"]
	h.session.from_dict(SaveCodec.decode(JSON.stringify(d))["data"])
	var crop := _rec.records.filter(func(x): return x["name"] == &"trophy_unlocked" and x["args"][0] == &"trophy_crop_set")
	assert_int(crop.size()).is_equal(1)
	var rewards := _reward_letters().filter(func(m): return m["params"].get("trophy_id", "") == "trophy_crop_set")
	assert_int(rewards.size()).is_equal(1)
	_rec.clear()
	await SaveService.save_slot(1, h.session)
	h.session.from_dict(SaveService.load_slot(1).data["data"])
	assert_int(_rec.count(&"trophy_unlocked")).is_equal(0)
	assert_int(_reward_letters().filter(func(m): return m["params"].get("trophy_id", "") == "trophy_crop_set").size()).is_equal(1)


func test_c15_discovery_tracking() -> void:
	h.session.inventory.add(&"item_apple", 1)
	h.session.inventory.add(&"item_apple", 1)
	var disc := _rec.records.filter(func(x): return x["name"] == &"entry_discovered")
	assert_int(disc.size()).is_equal(1)
	assert_array(disc[0]["args"]).contains_exactly([&"item_apple"])


func test_c16_mineral_from_voxel_ore() -> void:
	h.world.set_voxel(Vector3i(0, -1, 0), h.vid(&"mat_quartz_ore"))
	h.session.toolbelt.model.grant(&"item_pickaxe_copper")
	var pick := h.session.toolbelt.model.tool_data(ToolTypes.PICKAXE)
	var n := 0
	while h.world.get_voxel(Vector3i(0, -1, 0)) != 0 and n < 20:
		h.session.terrain.hit_voxel(Vector3i(0, -1, 0), pick)
		n += 1
	assert_int(h.session.inventory.count(&"item_quartz")).is_equal(1)
	assert_int(_rec.records.filter(func(x): return x["name"] == &"entry_discovered" and x["args"][0] == &"item_quartz").size()).is_equal(1)
	assert_bool(_m().try_donate(&"item_quartz").ok).is_true()


func test_c17_geode_mineral_undiscovered_bias() -> void:
	for id in [&"item_quartz", &"item_amethyst", &"item_agate", &"item_jasper"]:
		h.session.collection.mark_discovered(id)
	h.session.inventory.add(&"item_geode", 1)
	h.session.rng = RngStreams.new(12)
	# find a seed state whose draw is the undiscovered topaz, proving the bias path end to end
	var found := false
	for seed_v in range(1, 400):
		h.session.rng = RngStreams.new(seed_v)
		var probe := RngStreams.new(seed_v)
		if GeodeModel.open(&"item_geode", h.session.collection.model, probe) == &"item_topaz":
			found = true
			break
	assert_bool(found).is_true()
	_rec.clear()
	var r := _m().open_geode()
	assert_str(r.data).is_equal(&"item_topaz")
	assert_int(h.session.inventory.count(&"item_topaz")).is_equal(1)
	assert_int(h.session.inventory.count(&"item_geode")).is_equal(0)
	assert_int(_rec.records.filter(func(x): return x["name"] == &"entry_discovered" and x["args"][0] == &"item_topaz").size()).is_equal(1)
