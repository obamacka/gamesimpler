# P5.20: mail delivery, catalog orders, job offers, pet adoption, full-inventory claims.
extends GdUnitTestSuite

var h: Phase2Harness
var _rec: SignalRecorder


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	PetFixture.setup(h)
	_rec = SignalRecorder.new(EventBus, [&"mail_delivered", &"pet_adopted"])


func after_test() -> void:
	_rec.stop()
	h.stop()
	await get_tree().process_frame


func test_delivery_on_its_day_in_id_order_one_signal() -> void:
	var tpl: MailTemplateDef = Database.mail_templates[&"mail_tpl_catalog_order"]
	GameClock.model.set_time(5, 600)
	var b := h.session.mail.schedule(tpl, 7)
	var a := h.session.mail.schedule(tpl, 6)
	h.session.mail.deliver_due(5)
	assert_dict(h.session.mail.model.find(a)).is_empty()
	_rec.clear()
	h.session.mail.deliver_due(7)
	assert_int(_rec.count(&"mail_delivered")).is_equal(1)
	assert_array(_rec.records[0]["args"][0]).is_equal([b, a] if b < a else [a, b])


func test_adoption_letter_day_two_and_adopt_through_menu() -> void:
	h.session.mail.model.inbox.clear()
	h.session.mail.model.scheduled.clear()
	h.session.new_game()   # day 1: welcome letter; adoption scheduled for day 2
	assert_bool(h.session.mail.model.inbox.any(func(m): return m["template_id"] == "mail_tpl_pet_adoption")).is_false()
	h.session.rollover.run(2)
	var letter: Array = h.session.mail.model.inbox.filter(func(m): return m["template_id"] == "mail_tpl_pet_adoption")
	assert_int(letter.size()).is_equal(1)
	h.session.pets.path_override = PetPathProvider.new()
	var mail: MenuBase = h.menus.push(&"mail")
	mail.open(letter[0]["id"])
	assert_bool(mail.claim(letter[0]["id"]).ok).is_true()
	assert_str(h.menus.top().menu_id).is_equal(&"pet_adoption")
	assert_bool(h.menus.top().choose(&"pet_cat", 1, "Mochi").ok).is_true()
	assert_int(_rec.count(&"pet_adopted")).is_equal(1)
	assert_str(h.session.pets.pet()["name"]).is_equal("Mochi")
	assert_bool(is_instance_valid(h.session.pets.node)).is_true()
	h.menus.close_all()


func test_job_offer_contract_attachment() -> void:
	var id := h.session.mail.schedule(Database.mail_templates[&"mail_tpl_job_offer_tailor"], 1)
	h.session.mail.deliver_due(1)
	assert_bool(h.session.mail.claim(id).ok).is_true()
	assert_bool(h.session.jobs.find_active(&"contract_tailor_bandanas").is_empty()).is_false()


func test_catalog_order_next_day() -> void:
	h.session.wallet.model.coins = 100
	GameClock.model.set_time(3, 600)
	var r := h.session.mail.order(&"shop_general", &"item_fish_treat", 3)
	h.session.rollover.run(4)
	assert_dict(h.session.mail.model.find(r.data)).is_not_empty()
	h.session.mail.claim(r.data)
	assert_int(h.session.inventory.count(&"item_fish_treat")).is_equal(3)


func test_full_inventory_claim_changes_nothing() -> void:
	var id := h.session.mail.schedule(Database.mail_templates[&"mail_tpl_welcome"], 1)
	h.session.mail.deliver_due(1)
	for i in h.session.inventory.model.slots.size():
		h.session.inventory.model.slots[i] = {"item_id": &"item_stone", "qty": 99, "data": {}}
	var before := h.session.inventory.model.to_dict()
	var mail: MenuBase = h.menus.push(&"mail")
	mail.open(id)
	assert_str(mail.claim(id).error).is_equal(&"no_space")
	assert_str(mail.status.text).is_equal("Make room in your backpack first")
	assert_dict(h.session.inventory.model.to_dict()).is_equal(before)
	assert_bool(h.session.mail.model.find(id)["claimed"]).is_false()
	h.menus.close_all()
