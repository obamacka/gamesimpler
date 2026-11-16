# P4.16: wallet, shop stock, jobs, deeds, outfit, containers and settings round-trip.
extends GdUnitTestSuite


func test_phase4_sections() -> void:
	var a: GameSession = auto_free(GameSession.create(6))
	add_child(a)
	a.new_game()
	a.wallet.model.coins = 2000
	a.economy.tx.try_buy(&"shop_general", &"item_seed_carrot", 4)
	a.economy.tx.try_buy_plot(&"plot_meadow_east")
	a.jobs.accept_contract(&"contract_tailor_bandanas")
	a.jobs.jobs["job_tailor"] = {"rank": 1, "xp": 140}
	a.inventory.add(&"item_outfit_scarf", 1, {"dye": "dye_moss"})
	a.outfit.equip_from_slot(a.inventory.model.slots.find(a.inventory.model.slots.filter(func(s): return s and s["item_id"] == &"item_outfit_scarf")[0]))
	a.storage.containers["p0001"] = InventoryModel.new(3)
	a.storage.containers["p0001"].add(&"item_wood", 5)
	var d := a.to_dict()
	var b: GameSession = auto_free(GameSession.create(1))
	add_child(b)
	b.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_int(b.wallet.model.coins).is_equal(a.wallet.model.coins)
	assert_dict(b.economy.stock_to_dict()).is_equal(a.economy.stock_to_dict())
	assert_dict(b.jobs.to_dict()).is_equal(a.jobs.to_dict())
	assert_bool(b.housing.owns(&"plot_meadow_east")).is_true()
	assert_dict(b.outfit.model.to_dict()).is_equal(a.outfit.model.to_dict())
	assert_dict(b.storage.to_dict()).is_equal(a.storage.to_dict())
	assert_int(typeof(b.jobs.active[0]["deadline_day"])).is_equal(TYPE_INT)
	assert_int(typeof(b.economy.stock["shop_general"]["remaining"]["item_seed_carrot"])).is_equal(TYPE_INT)


func test_settings_additions_round_trip() -> void:
	var m := SettingsModel.new()
	assert_bool(m.set_value("accessibility", "text_scale", 1.5)).is_true()
	assert_bool(m.set_value("assist", "snap_strength", "low")).is_true()
	assert_bool(m.set_value("audio", "master", 0.5)).is_true()
	var n := SettingsModel.new()
	n.from_dict(m.to_dict())
	assert_dict(n.to_dict()).is_equal(m.to_dict())
