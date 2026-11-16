# P2.28: every Phase 2 model round-trips through JSON text; integers stay TYPE_INT.
extends GdUnitTestSuite


func _session(seed_value: int = 7) -> GameSession:
	var s := GameSession.create(seed_value)
	add_child(s)
	return auto_free(s)


func test_session_round_trip() -> void:
	var a := _session()
	a.new_game()
	a.inventory.add(&"item_apple", 6)
	a.toolbelt.model.grant(&"item_pickaxe_copper")
	a.wallet.model.coins = 1340
	a.unlocks.model.grant(&"STICKER", &"sticker_star")
	a.stamina.model.current = 82
	a.stamina.model.bonus = 10
	a.terrain.dig.damage[Vector3i(12, 4, -7)] = 1
	a.world_state.fruit["zone_orchard/tree_004"] = {"def": "tree_apple", "fruit": 0, "regrow_day": 17}
	a.world_state.spawn_chest(Vector3i(4, 2, 9), &"zone_wilderness")
	a.world_state.spawn_chest(Vector3i(1, 1, 1), &"zone_deep_mine")
	a.discovery.model.pity_geode = 3
	a.exhaustion = {"last_snack_day": 13, "count_total": 3}
	a.mail.schedule(Database.mail_templates[&"mail_tpl_care_neighbor_01"], 2)
	a.rng.randi_range("loot", 0, 9)
	GameClock.model.set_time(14, 545)
	var text := JSON.stringify(a.to_dict())
	var b := _session(1)
	b.from_dict(JSON.parse_string(text))
	assert_dict(b.to_dict()).is_equal(a.to_dict())
	assert_int(typeof(b.wallet.model.coins)).is_equal(TYPE_INT)
	assert_int(typeof(b.stamina.model.current)).is_equal(TYPE_INT)
	assert_int(typeof(b.inventory.model.slots[0]["qty"])).is_equal(TYPE_INT)
	assert_int(typeof(b.world_state.chests.values()[0]["cell"][0])).is_equal(TYPE_INT)


func test_deep_mine_chests_are_not_saved() -> void:
	var a := _session()
	a.world_state.spawn_chest(Vector3i(1, 1, 1), &"zone_deep_mine")
	assert_dict(a.to_dict()["world"]["chests"]).is_empty()
