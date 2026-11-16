# P2.27: ids, scheduled delivery idempotence, all-or-nothing claim, care pools.
extends GdUnitTestSuite


func _tpl(attachments: Array) -> MailTemplateDef:
	var t := MailTemplateDef.new()
	t.id = &"mail_tpl_test"
	t.kind = &"CARE_PACKAGE"
	t.attachments = attachments
	return t


func _inv(slots: int = 4) -> InventoryModel:
	return InventoryModel.new(slots, func(_id): return 10)


func test_ids_are_monotonic() -> void:
	var m := MailboxModel.new()
	assert_str(m.schedule(_tpl([]), 1, 2)).is_equal("m_000001")
	assert_str(m.schedule(_tpl([]), 1, 2)).is_equal("m_000002")


func test_delivery_idempotent_and_ordered() -> void:
	var m := MailboxModel.new()
	m.schedule(_tpl([]), 1, 3)
	m.schedule(_tpl([]), 1, 2)
	assert_array(m.deliver_due(1)).is_empty()
	assert_array(m.deliver_due(3)).contains_exactly(["m_000001", "m_000002"])
	assert_array(m.deliver_due(3)).is_empty()
	assert_int(m.inbox.size()).is_equal(2)
	assert_int(m.unread_count()).is_equal(2)


func test_care_package_never_expires() -> void:
	var m := MailboxModel.new()
	m.schedule(_tpl([]), 1, 2)
	assert_int(m.scheduled[0]["expires_day"]).is_equal(0)


func test_claim_all_or_nothing() -> void:
	var m := MailboxModel.new()
	m.schedule(_tpl([{"type": "item", "item_id": "item_a", "qty": 5}, {"type": "item", "item_id": "item_b", "qty": 25}, {"type": "coins", "amount": 50}]), 1, 1)
	m.deliver_due(1)
	var inv := _inv(2)    # 2 slots of 10 cannot hold 5 + 25
	var wallet := WalletModel.new()
	var r := m.claim("m_000001", inv, wallet)
	assert_str(r.error).is_equal(&"no_space")
	assert_int(inv.count(&"item_a")).is_equal(0)
	assert_int(wallet.coins).is_equal(0)
	var big := _inv(6)
	assert_bool(m.claim("m_000001", big, wallet).ok).is_true()
	assert_int(big.count(&"item_b")).is_equal(25)
	assert_int(wallet.coins).is_equal(50)
	assert_str(m.claim("m_000001", big, wallet).error).is_equal(&"already_claimed")
	assert_str(m.claim("m_999999", big, wallet).error).is_equal(&"not_found")


func test_snack_once_per_day_pool_choice() -> void:
	# Collapsing on day 5 with no snack yet: snack. Collapsing on day 6 after a snack arrived on day 6: none.
	assert_str(CareLetterModel.pool_for(&"exhausted", 5, 0)).is_equal(&"pool_care_exhausted")
	assert_str(CareLetterModel.pool_for(&"exhausted", 6, 6)).is_equal(&"pool_care_exhausted_repeat")
	assert_str(CareLetterModel.pool_for(&"exhausted", 7, 6)).is_equal(&"pool_care_exhausted")
	assert_str(CareLetterModel.pool_for(&"late_night", 6, 5)).is_equal(&"pool_care_late_night")
	assert_str(CareLetterModel.pool_for(&"bed", 6, 5)).is_equal(&"")


func test_round_trip_casts_ints() -> void:
	var m := MailboxModel.new()
	m.schedule(_tpl([{"type": "item", "item_id": "item_a", "qty": 1}]), 4, 5)
	m.deliver_due(5)
	var m2 := MailboxModel.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_int(typeof(m2.inbox[0]["deliver_day"])).is_equal(TYPE_INT)
	assert_int(typeof(m2.inbox[0]["attachments"][0]["qty"])).is_equal(TYPE_INT)
	assert_int(m2.next_seq).is_equal(2)
