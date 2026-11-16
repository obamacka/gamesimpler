# P5.17: mail attachment types, all-or-nothing, expiry to Lost and Found, never-expire kinds,
# prune rules, monotonic ids across a save round trip.
extends GdUnitTestSuite

var s: GameSession


func before_test() -> void:
	s = GameSession.create(4)
	add_child(s)
	s.new_game()


func after_test() -> void:
	s.queue_free()


func _tpl(kind: String, attachments: Array, expires: int = 0) -> MailTemplateDef:
	var t := MailTemplateDef.new()
	t.id = &"mail_tpl_test"
	t.kind = StringName(kind)
	t.attachments = attachments
	t.expires_after_days = expires
	return t


func _deliver(t: MailTemplateDef, day: int = 1) -> String:
	var id := s.mail.schedule(t, day)
	s.mail.deliver_due(day)
	return id


func test_all_attachment_types() -> void:
	var id := _deliver(_tpl("REWARD", [{"type": "item", "item_id": "item_apple", "qty": 2}, {"type": "coins", "amount": 30},
		{"type": "unlock_recipe", "id": "recipe_piece_lamp"}, {"type": "unlock_dye", "id": "dye_plum"},
		{"type": "unlock_sticker", "id": "sticker_star"}, {"type": "unlock_emote", "id": "emote_point"},
		{"type": "contract", "contract_id": "contract_tailor_cloth"}]))
	var coins := s.wallet.model.coins
	assert_bool(s.mail.claim(id).ok).is_true()
	assert_int(s.inventory.count(&"item_apple")).is_equal(2)
	assert_int(s.wallet.model.coins).is_equal(coins + 30)
	assert_bool(s.unlocks.model.is_unlocked(&"BLUEPRINT", &"recipe_piece_lamp")).is_true()
	assert_bool(s.unlocks.model.is_unlocked(&"DYE", &"dye_plum")).is_true()
	assert_bool(s.unlocks.model.is_unlocked(&"STICKER", &"sticker_star")).is_true()
	assert_bool(s.unlocks.model.is_unlocked(&"EMOTE", &"emote_point")).is_true()
	assert_bool(s.jobs.find_active(&"contract_tailor_cloth").is_empty()).is_false()


func test_pet_adoption_attachment_signals() -> void:
	var got := [0]
	var cb := func(): got[0] += 1
	EventBus.pet_adoption_claimed.connect(cb)
	s.mail.claim(_deliver(_tpl("PACKAGE", [{"type": "pet_adoption"}])))
	EventBus.pet_adoption_claimed.disconnect(cb)
	assert_int(got[0]).is_equal(1)


func test_mixed_attachments_all_or_nothing() -> void:
	for i in s.inventory.model.slots.size():
		s.inventory.model.slots[i] = {"item_id": &"item_stone", "qty": 99, "data": {}}
	var coins := s.wallet.model.coins
	var id := _deliver(_tpl("REWARD", [{"type": "item", "item_id": "item_apple", "qty": 1}, {"type": "coins", "amount": 30},
		{"type": "unlock_emote", "id": "emote_point"}]))
	assert_str(s.mail.claim(id).error).is_equal(&"no_space")
	assert_int(s.wallet.model.coins).is_equal(coins)
	assert_bool(s.unlocks.model.is_unlocked(&"EMOTE", &"emote_point")).is_false()
	assert_bool(s.mail.model.find(id)["claimed"]).is_false()


func test_expiry_to_lost_and_found_and_never_expire_kinds() -> void:
	var offer := _deliver(_tpl("JOB_OFFER", [{"type": "item", "item_id": "item_wood", "qty": 3}], 2), 1)
	var care := _deliver(_tpl("CARE_PACKAGE", [{"type": "item", "item_id": "item_honey_bun", "qty": 1}], 2), 1)
	assert_int(s.mail.model.find(care)["expires_day"]).is_equal(0)
	s.mail.deliver_due(3)
	assert_bool(s.mail.model.find(offer)["archived"]).is_false()   # expires after day 3
	s.mail.deliver_due(4)
	assert_bool(s.mail.model.find(offer)["archived"]).is_true()
	assert_array(s.mail.model.find(offer)["attachments"]).is_empty()
	assert_int(s.mail.model.lost_and_found.size()).is_equal(1)
	assert_bool(s.mail.model.find(care)["archived"]).is_false()
	assert_bool(s.mail.claim_lost_and_found().ok).is_true()
	assert_int(s.inventory.count(&"item_wood")).is_equal(3)


func test_prune_only_archived_and_claimed() -> void:
	var keep := _deliver(_tpl("LETTER", []))
	for i in MailboxModel.INBOX_CAP + 5:
		var id := _deliver(_tpl("LETTER", []))
		s.mail.claim(id)
		s.mail.archive(id)
	var unclaimed := _deliver(_tpl("LETTER", [{"type": "item", "item_id": "item_apple", "qty": 1}]))
	s.mail.deliver_due(2)
	assert_int(s.mail.model.inbox.size()).is_less_equal(MailboxModel.INBOX_CAP)
	assert_dict(s.mail.model.find(keep)).is_not_empty()
	assert_dict(s.mail.model.find(unclaimed)).is_not_empty()


func test_monotonic_ids_across_round_trip() -> void:
	var a := s.mail.schedule(_tpl("LETTER", []), 2)
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.mail.model.to_dict()))
	var m := MailboxModel.new()
	m.from_dict(d)
	var b := m.schedule(_tpl("LETTER", []), 1, 2)
	assert_bool(b > a).is_true()
	assert_int(typeof(m.next_seq)).is_equal(TYPE_INT)


func test_catalog_order_debits_now_and_arrives_next_day() -> void:
	s.wallet.model.coins = 100
	GameClock.model.set_time(3, 600)
	var price := s.economy.tx.buy_quote(&"shop_general", &"item_kibble", 2)
	var r := s.mail.order(&"shop_general", &"item_kibble", 2)
	assert_bool(r.ok).is_true()
	assert_int(s.wallet.model.coins).is_equal(100 - price)
	assert_int(s.inventory.count(&"item_kibble")).is_equal(0)
	s.mail.deliver_due(4)
	var m := s.mail.model.find(r.data)
	assert_str(m["kind"]).is_equal("CATALOG_ORDER")
	s.mail.claim(r.data)
	assert_int(s.inventory.count(&"item_kibble")).is_equal(2)
