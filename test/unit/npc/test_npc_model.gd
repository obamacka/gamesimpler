# P5.17: friendship, one gift per day, preferences, waves, talks.
extends GdUnitTestSuite

var m: NpcModel
var hilde: NpcDef
var cfg: Dictionary


func before_test() -> void:
	m = NpcModel.new()
	hilde = Database.npcs[&"npc_hilde"]
	cfg = Database.friendship


func test_gift_preferences_and_once_per_day() -> void:
	var r := m.gift(hilde, Database.item(&"item_berry_tart"), 3, cfg)
	assert_str(r["pref"]).is_equal(&"loved")
	assert_int(r["gain"]).is_equal(80)
	assert_str(m.gift(hilde, Database.item(&"item_apple"), 3, cfg)["reason"]).is_equal(NpcModel.ALREADY_GIFTED)
	assert_int(m.gift(hilde, Database.item(&"item_apple"), 4, cfg)["gain"]).is_equal(45)
	assert_int(m.gift(hilde, Database.item(&"item_wood"), 5, cfg)["gain"]).is_equal(20)
	assert_int(m.gift(hilde, Database.item(&"item_stone"), 6, cfg)["gain"]).is_equal(0)
	assert_int(m.of(&"npc_hilde")["friendship"]).is_equal(145)
	assert_str(m.gift(hilde, Database.item(&"item_hammer_basic"), 7, cfg)["reason"]).is_equal(NpcModel.NOT_GIFTABLE)


func test_talk_and_wave_daily() -> void:
	assert_int(m.talk(&"npc_hilde", 2, cfg)).is_equal(5)
	assert_int(m.talk(&"npc_hilde", 2, cfg)).is_equal(0)
	assert_bool(m.of(&"npc_hilde")["met"]).is_true()
	assert_int(m.wave(&"npc_hilde", 2, cfg)).is_equal(1)
	assert_int(m.wave(&"npc_hilde", 2, cfg)).is_equal(0)
	assert_int(m.wave(&"npc_hilde", 3, cfg)).is_equal(1)


func test_cap_best_friend_and_round_trip() -> void:
	m.of(&"npc_tailor")["friendship"] = 990
	m.gift(Database.npcs[&"npc_tailor"], Database.item(&"item_cotton_cloth"), 1, cfg)
	assert_int(m.of(&"npc_tailor")["friendship"]).is_equal(1000)
	m.talk(&"npc_hilde", 1, cfg)
	assert_str(m.best_friend()).is_equal(&"npc_tailor")
	assert_int(m.hearts(&"npc_tailor")).is_equal(10)
	var b := NpcModel.new()
	b.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_dict(b.to_dict()).is_equal(m.to_dict())
	assert_int(typeof(b.of(&"npc_tailor")["friendship"])).is_equal(TYPE_INT)
