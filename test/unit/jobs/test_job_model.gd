# P4.16: job XP thresholds; blueprint completion needs every piece FASTENED; deadline
# extension on exhaustion (spec 8.4 B13).
extends GdUnitTestSuite


func test_xp_thresholds() -> void:
	var j: JobDef = Database.jobs[&"job_builder"]   # 0, 100, 300, 700
	var st := {"rank": 0, "xp": 0}
	assert_int(JobModel.add_xp(j, st, 99)).is_equal(0)
	assert_int(JobModel.add_xp(j, st, 1)).is_equal(1)
	assert_int(st["rank"]).is_equal(1)
	assert_int(JobModel.add_xp(j, st, 700)).is_equal(2)
	assert_int(st["rank"]).is_equal(3)
	assert_int(JobModel.next_threshold(j, 3)).is_equal(-1)
	assert_int(JobModel.rank_for(j, 299)).is_equal(1)


func test_blueprint_needs_all_pieces_fastened() -> void:
	var s: GameSession = auto_free(GameSession.create(2))
	add_child(s)
	s.new_game()
	SceneRouter.current_zone_id = &"zone_home_meadow"
	(s.terrain.world as FakeVoxelWorld).fill(Vector3i(14, -1, 4), Vector3i(24, -1, 14), Database.voxel_id_of(&"mat_grass"))
	assert_bool(s.jobs.accept_contract(&"contract_builder_shed").ok).is_true()
	var a := s.jobs.find_active(&"contract_builder_shed")
	assert_int(a["origin_y"]).is_equal(0)
	var done := [0]
	var cb := func(_id, _pay): done[0] += 1
	EventBus.contract_completed.connect(cb)
	var uids: Array = []
	for need in s.jobs.blueprint_cells(a):
		s.inventory.add(Database.pieces[need["piece_id"]].item_id, 1)
		uids.append(s.build.try_place(need["piece_id"], need["cell"], need["rot"]).data)
	assert_bool(uids.all(func(u): return u != null)).is_true()
	assert_bool(s.jobs.blueprint_done(a)).is_false()
	for uid in uids:
		var def := s.build.def_of(uid)
		for i in def.fastener_sockets.size():
			for k in def.hits_per_socket:
				s.build.fasten_step(uid, i)
		if uid != uids.back():
			assert_int(done[0]).is_equal(0)
	EventBus.contract_completed.disconnect(cb)
	assert_int(done[0]).is_equal(1)
	assert_bool(s.jobs.find_active(&"contract_builder_shed").is_empty()).is_true()
	SceneRouter.current_zone_id = &""


func test_deadline_extension_and_expiry() -> void:
	var s: GameSession = auto_free(GameSession.create(2))
	add_child(s)
	s.new_game()
	GameClock.model.set_time(2, 600)
	s.jobs.accept_contract(&"contract_tailor_cloth")   # 3 days -> due day 5
	var a := s.jobs.find_active(&"contract_tailor_cloth")
	assert_int(a["deadline_day"]).is_equal(5)
	s.jobs.extend_deadlines(5)
	assert_int(a["deadline_day"]).is_equal(6)
	s.jobs.expire_due(6)
	assert_bool(s.jobs.find_active(&"contract_tailor_cloth").is_empty()).is_false()
	s.jobs.expire_due(7)
	assert_bool(s.jobs.find_active(&"contract_tailor_cloth").is_empty()).is_true()
