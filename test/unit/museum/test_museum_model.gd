# P6.11: donation guards, cases, trophies, rewards (spec 6.5).
extends GdUnitTestSuite

var m: MuseumModel
var inv: InventoryModel


func before_test() -> void:
	m = MuseumModel.new()
	inv = InventoryModel.new(8)


func test_guard_order() -> void:
	assert_str(m.donate(&"item_wood", inv, 1)["reason"]).is_equal(MuseumModel.NOT_COLLECTIBLE)
	assert_str(m.donate(&"item_quartz", inv, 1)["reason"]).is_equal(MuseumModel.NOT_IN_INVENTORY)
	inv.add(&"item_quartz", 2)
	assert_bool(m.donate(&"item_quartz", inv, 1)["ok"]).is_true()
	var before := inv.to_dict()
	assert_str(m.donate(&"item_quartz", inv, 1)["reason"]).is_equal(MuseumModel.ALREADY)   # checked before inventory
	assert_dict(inv.to_dict()).is_equal(before)
	assert_int(inv.count(&"item_quartz")).is_equal(1)   # exactly one removed
	inv.remove(&"item_quartz", 1)
	assert_str(m.donate(&"item_quartz", inv, 2)["reason"]).is_equal(MuseumModel.ALREADY)   # not owned, still already_donated first


func test_plain_stack_preferred_and_dye_ignored() -> void:
	inv.add(&"item_cotton_cloth", 1, {"dye": "dye_sky"})
	inv.add(&"item_cotton_cloth", 1)
	assert_bool(m.donate(&"item_cotton_cloth", inv, 1)["ok"]).is_true()
	var left: Array = inv.slots.filter(func(s): return s != null)
	assert_int(left.size()).is_equal(1)
	assert_dict(left[0]["data"]).is_equal({"dye": "dye_sky"})   # the plain stack went
	assert_str(m.donate(&"item_cotton_cloth", inv, 1)["reason"]).is_equal(MuseumModel.ALREADY)   # dyed = same entry


func test_case_and_trophy_once() -> void:
	inv.add(&"item_quartz", 1)
	inv.add(&"item_amethyst", 1)
	var r1 := m.donate(&"item_quartz", inv, 1)
	assert_array(r1["trophies"]).contains_exactly([&"trophy_first_donation"])
	assert_array(r1["cases"]).is_empty()
	var r2 := m.donate(&"item_amethyst", inv, 1)
	assert_array(r2["cases"]).contains_exactly([&"case_minerals"])
	assert_array(r2["trophies"]).is_empty()
	assert_dict(m.evaluate()).is_equal({"cases": [], "trophies": []})


func test_rewards_guard() -> void:
	inv.add(&"item_quartz", 1)
	m.donate(&"item_quartz", inv, 1)
	assert_array(m.pending_rewards()).contains_exactly(["trophy_first_donation"])
	m.rewards_granted.append("trophy_first_donation")
	assert_array(m.pending_rewards()).is_empty()


func test_reconcile_unlocks_new_content_once() -> void:
	m.donated = {"item_carrot": 3, "item_sunflower": 3, "item_pumpkin": 3, "item_cotton": 3, "item_strawberry": 3, "item_tomato": 3}
	var r := m.evaluate()   # as after loading a save made before these trophies existed
	assert_array(r["trophies"]).contains([&"trophy_crop_set", &"trophy_first_donation"])
	assert_array(r["cases"]).contains([&"case_produce"])
	assert_dict(m.evaluate()).is_equal({"cases": [], "trophies": []})


func test_set_and_all_complete() -> void:
	for it in Database.collectibles():
		m.donated[String(it.id)] = 1
	var r := m.evaluate()
	assert_array(r["trophies"]).contains([&"trophy_all", &"trophy_gems", &"trophy_crop_set"])
	assert_array(m.cases_unlocked).contains(["case_minerals", "case_fabrics", "case_produce"])


func test_round_trip_ints() -> void:
	inv.add(&"item_quartz", 1)
	m.donate(&"item_quartz", inv, 4)
	var b := MuseumModel.new()
	b.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_dict(b.to_dict()).is_equal(m.to_dict())
	assert_int(typeof(b.donated["item_quartz"])).is_equal(TYPE_INT)
