# P6.15: a session touching every system saves to user://test_tmp/, loads into a fresh
# session, and every section is equal; a second save is byte-identical apart from the voxel
# epoch.
extends GdUnitTestSuite

const DIR := "user://test_tmp/roundtrip"

var h: Phase2Harness


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	SaveService.base_dir = DIR
	VoxelPersistence.remove_dir(DIR)
	BuildFixture.setup(h)


func after_test() -> void:
	VoxelPersistence.remove_dir(DIR)
	h.stop()
	await get_tree().process_frame


func _touch_everything() -> void:
	var s := h.session
	GameClock.model.set_time(9, 777)
	s.rng.randi_range("loot", 0, 9)
	s.rng.randi_range("pet", 0, 9)
	s.stamina.model.current = 63
	s.stamina.model.bonus = 10
	s.exhaustion = {"last_snack_day": 8, "count_total": 2}
	s.housing.set_home_bed(&"zone_home_meadow", &"p0009")
	s.toolbelt.model.grant(&"item_pickaxe_copper")
	s.inventory.add(&"item_outfit_scarf", 1, {"dye": "dye_sky"})
	var scarf := -1
	for i in s.inventory.model.slots.size():
		if s.inventory.model.slots[i] and s.inventory.model.slots[i]["item_id"] == &"item_outfit_scarf":
			scarf = i
	s.outfit.equip_from_slot(scarf)
	s.inventory.add(&"item_outfit_hat_straw", 1, {"dye": "dye_berry"})
	s.inventory.add(&"item_apple", 5)
	s.wallet.model.coins = 4321
	s.unlocks.model.grant(&"DYE", &"dye_plum")
	s.unlocks.model.grant(&"BLUEPRINT", &"recipe_piece_lamp")
	var wall := BuildFixture.place_fastened(h, &"piece_wall", Vector3i(-8, 0, 14), 1)
	s.inventory.add(&"item_piece_floor", 1)
	var loose: String = s.build.try_place(&"piece_floor", Vector3i(-6, 0, 14), 0).data
	s.build.fasten_step(loose, 0)
	var lamp := BuildFixture.place_fastened(h, &"piece_lamp", Vector3i(-10, 0, 12), 2)
	s.build.toggle_furniture(lamp)
	s.build.try_paint(wall, &"PRIMARY", &"dye_plum")
	s.build.try_stamp(wall, &"sticker_flower", Vector3(0, 1.2, -0.43), Vector3.FORWARD, 45, "S")
	var chest := BuildFixture.place_fastened(h, &"piece_chest", Vector3i(-11, 0, 17), 0)
	s.storage.container(chest).add(&"item_wood", 7)
	s.world_state.fruit["zone_orchard/tree_004"] = {"def": "tree_apple", "fruit": 0, "regrow_day": 11}
	s.world_state.spawn_chest(Vector3i(4, 2, 9), &"zone_wilderness")
	s.terrain.dig.damage[Vector3i(1, -1, 1)] = 1
	s.discovery.model.pity_geode = 7
	s.inventory.add(&"item_quartz", 1)
	s.museum.try_donate(&"item_quartz")
	s.farm.try_till(Vector3i(5, -1, 0), &"")
	s.pets.path_override = PetPathProvider.new()
	s.pets.adopt(&"pet_cat", 2, "Mochi")
	s.inventory.add(&"item_petacc_beanie", 1, {"dye": "dye_sun"})
	for i in s.inventory.model.slots.size():
		if s.inventory.model.slots[i] and s.inventory.model.slots[i]["item_id"] == &"item_petacc_beanie":
			s.pets.equip_accessory(i)
			break
	s.jobs.accept_contract(&"contract_tailor_cloth")
	s.mail.schedule(Database.mail_templates[&"mail_tpl_catalog_order"], 12, {"attachments": [{"type": "item", "item_id": "item_kibble", "qty": 2}]})
	s.npcs.try_gift(&"npc_hilde", &"item_apple")
	s.economy.tx.try_buy(&"shop_general", &"item_seed_carrot", 2)
	s.hotbar.select(3)


func _sections_without_transform(d: Dictionary) -> Dictionary:
	var c := d.duplicate(true)
	for k in ["zone_id", "position", "yaw", "ducking"]:
		c["player"].erase(k)
	c.erase("voxel")
	return c


func test_every_section_round_trips() -> void:
	_touch_everything()
	await h.frames(2)
	var original := h.session.to_dict()
	assert_bool((await SaveService.save_slot(2, h.session)).ok).is_true()
	var r := SaveService.load_slot(2)
	assert_bool(r.ok).is_true()
	var loaded: Dictionary = r.data["data"]
	var fresh: GameSession = auto_free(GameSession.create(1))
	add_child(fresh)
	fresh.from_dict(loaded)
	var a := _sections_without_transform(JSON.parse_string(SaveCodec.encode(original)))
	var b := _sections_without_transform(JSON.parse_string(SaveCodec.encode(fresh.to_dict())))
	for k in a:
		assert_that(b[k]).override_failure_message("section %s differs after load" % k).is_equal(a[k])
	assert_array(loaded["player"]["position"]).is_equal(original["player"]["position"])
	assert_str(loaded["player"]["zone_id"]).is_equal("zone_home_meadow")


func test_second_save_byte_identical() -> void:
	_touch_everything()
	await SaveService.save_slot(1, h.session)
	var first := FileAccess.get_file_as_string(SaveService.paths(1)["json"])
	await SaveService.save_slot(1, h.session)
	var second := FileAccess.get_file_as_string(SaveService.paths(1)["json"])
	var strip := func(t: String) -> String:
		var d: Dictionary = JSON.parse_string(t)
		d.erase("voxel")
		return SaveCodec.encode(d)
	assert_str(strip.call(second)).is_equal(strip.call(first))
	assert_str(first).is_not_equal(second)   # only the epoch moved


func test_load_into_moves_player() -> void:
	_touch_everything()
	h.place(Vector3(-6.5, 0, 16.5))
	await h.frames(2)
	await SaveService.save_slot(3, h.session)
	h.place(Vector3(0.5, 0, 0.5))
	await SceneRouter.change_zone(&"zone_starter_cabin", &"spawn_start")
	var r: Result = await SaveService.load_into(3, h.session)
	assert_bool(r.ok).is_true()
	assert_str(SceneRouter.current_zone_id).is_equal(&"zone_home_meadow")
	assert_float(h.player.global_position.distance_to(Vector3(-6.5, 0, 16.5))).is_less(0.6)
	assert_int(h.session.wallet.model.coins).is_greater(0)
