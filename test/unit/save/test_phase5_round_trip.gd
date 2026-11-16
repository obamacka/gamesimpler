# P5.17: NPC state, pet state, full mailbox and unlocked emotes/instruments round-trip.
extends GdUnitTestSuite


func test_phase5_sections() -> void:
	var a: GameSession = auto_free(GameSession.create(8))
	add_child(a)
	a.new_game()
	a.npcs.model.gift(Database.npcs[&"npc_hilde"], Database.item(&"item_apple"), 2, Database.friendship)
	a.pets.pets.append(a.pets.model.new_pet("pet_0001", &"pet_cat", 2, "Mochi"))
	a.pets.pets[0]["accessories"]["HEAD"] = {"item_id": "item_petacc_beanie", "data": {"dye": "dye_sun"}}
	a.pets.pets[0]["fed_day"] = 2
	a.mail.model.lost_and_found.append({"type": "item", "item_id": "item_wood", "qty": 2})
	a.unlocks.model.grant(&"EMOTE", &"emote_point")
	var d := a.to_dict()
	var b: GameSession = auto_free(GameSession.create(1))
	add_child(b)
	b.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_dict(b.npcs.model.to_dict()).is_equal(a.npcs.model.to_dict())
	assert_array(b.pets.to_dict()).is_equal(a.pets.to_dict())
	assert_dict(b.mail.model.to_dict()).is_equal(a.mail.model.to_dict())
	assert_bool(b.unlocks.model.is_unlocked(&"EMOTE", &"emote_point")).is_true()
	assert_bool(b.unlocks.model.is_unlocked(&"INSTRUMENT", &"inst_flute")).is_true()
	assert_int(typeof(b.pets.pet()["happiness"])).is_equal(TYPE_INT)
	assert_int(typeof(b.mail.model.lost_and_found[0]["qty"])).is_equal(TYPE_INT)
