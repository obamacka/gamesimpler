# P4.20: Builder and Tailor contracts end to end.
extends GdUnitTestSuite

var h: Phase2Harness
var _rec: SignalRecorder


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	h.world.fill(Vector3i(-16, -1, -8), Vector3i(26, -1, 16), h.vid(&"mat_grass"))
	GameClock.model.set_time(2, 9 * 60)
	h.session.wallet.model.coins = 0
	_rec = SignalRecorder.new(EventBus, [&"contract_completed", &"job_rank_up", &"mail_delivered", &"contract_accepted"])


func after_test() -> void:
	_rec.stop()
	h.stop()
	await get_tree().process_frame


func _letters(tpl: String) -> Array:
	return h.session.mail.model.inbox.filter(func(m): return m["template_id"] == tpl)


func test_builder_contract() -> void:
	var board: MenuBase = h.menus.push(&"job_board", {"job_id": &"job_builder"})
	assert_bool(board.accept(&"contract_builder_shed").ok).is_true()
	h.menus.close_all()
	assert_array(_letters("mail_tpl_job_materials")).is_empty()
	h.session.rollover.run(3)   # next morning
	var mats := _letters("mail_tpl_job_materials")
	assert_int(mats.size()).is_equal(1)
	assert_bool(h.session.mail.claim(mats[0]["id"]).ok).is_true()
	assert_int(h.session.inventory.count(&"item_piece_floor")).is_equal(2)
	var a := h.session.jobs.find_active(&"contract_builder_shed")
	var site_cell: Vector3i = h.session.jobs.blueprint_cells(a)[0]["cell"]
	assert_str(h.session.terrain.can_dig(site_cell + Vector3i.DOWN)).is_equal(TerrainRules.JOB_SITE)   # 9.3 P5
	h.player.global_position = Vector3(site_cell) + Vector3(0.5, 0, -0.5)
	await h.frames(3)
	assert_bool(h.player.context.in_build_zone).is_true()   # the job site is a build zone
	for need in h.session.jobs.blueprint_cells(a):
		var uid = h.session.build.try_place(need["piece_id"], need["cell"], need["rot"]).data
		var def := h.session.build.def_of(uid)
		for i in def.fastener_sockets.size():
			for k in def.hits_per_socket:
				h.session.build.fasten_step(uid, i)
	assert_int(_rec.count(&"contract_completed")).is_equal(1)
	assert_int(h.session.wallet.model.coins).is_equal(120)
	assert_int(h.session.jobs.jobs["job_builder"]["xp"]).is_equal(60)
	h.session.rollover.run(4)
	assert_int(_letters("mail_tpl_job_receipt").size()).is_equal(1)


func test_tailor_deliver_and_craft_contracts() -> void:
	h.session.jobs.accept_contract(&"contract_tailor_cloth")
	h.session.jobs.accept_contract(&"contract_tailor_bandanas")
	h.session.inventory.add(&"item_cotton", 10)
	for i in 5:
		assert_bool(h.session.economy.tx.try_craft(&"recipe_cotton_cloth", &"TAILOR_BENCH").ok).is_true()
	assert_str(h.session.jobs.submit_contract(&"contract_tailor_bandanas").error).is_equal(&"not_done")
	for i in 2:
		h.session.economy.tx.try_craft(&"recipe_petacc_bandana", &"TAILOR_BENCH")
	assert_bool(h.session.jobs.submit_contract(&"contract_tailor_bandanas").ok).is_true()
	assert_bool(h.session.jobs.submit_contract(&"contract_tailor_cloth").ok).is_true()
	assert_int(h.session.inventory.count(&"item_cotton_cloth")).is_equal(0)   # 5 made, 2 sewn, 3 delivered
	assert_int(h.session.wallet.model.coins).is_equal(170)
	assert_int(h.session.jobs.jobs["job_tailor"]["xp"]).is_equal(5 * 10 + 2 * 10 + 80)
	assert_int(h.session.jobs.rank(&"job_tailor")).is_equal(1)
	assert_int(_rec.count(&"job_rank_up")).is_equal(1)
	assert_bool(h.session.economy.tx.recipe_unlocked(Database.recipes[&"recipe_raincoat"])).is_true()   # rank-1 recipe


func test_abandon_loses_nothing() -> void:
	h.session.jobs.accept_contract(&"contract_builder_shed")
	h.session.rollover.run(3)
	h.session.mail.claim(_letters("mail_tpl_job_materials")[0]["id"])
	var inv := h.session.inventory.model.to_dict()
	assert_bool(h.session.jobs.abandon_contract(&"contract_builder_shed").ok).is_true()
	assert_dict(h.session.inventory.model.to_dict()).is_equal(inv)
	assert_bool(h.session.jobs.find_active(&"contract_builder_shed").is_empty()).is_true()
