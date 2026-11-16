# P6.16: corrupt primary falls back to .bak with a notice; saving is refused during a
# transition except the SleepDirector autosave; spec 8.4 B12 autosave content.
extends GdUnitTestSuite

const DIR := "user://test_tmp/failures"

var h: Phase2Harness


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_wilderness", &"spawn_start")
	SaveService.base_dir = DIR
	VoxelPersistence.remove_dir(DIR)
	h.world.fill(Vector3i(-10, -1, -10), Vector3i(10, -1, 10), h.vid(&"mat_dirt"))


func after_test() -> void:
	VoxelPersistence.remove_dir(DIR)
	h.stop()
	await get_tree().process_frame


func test_corrupt_primary_loads_bak_with_notice() -> void:
	h.session.wallet.model.coins = 10
	await SaveService.save_slot(1, h.session)
	h.session.wallet.model.coins = 20
	await SaveService.save_slot(1, h.session)
	var f := FileAccess.open(SaveService.paths(1)["json"], FileAccess.WRITE)
	f.store_string("[]")
	f.close()
	var notices: Array = []
	EventBus.game_loaded.connect(func(_s, n): notices.append_array(n))
	var r: Result = await SaveService.load_into(1, h.session)
	assert_bool(r.ok).is_true()
	assert_int(h.session.wallet.model.coins).is_equal(10)
	assert_array(notices).contains([&"backup_used"])


func test_refused_during_transition_except_autosave() -> void:
	PauseManager.request_pause(PauseManager.TRANSITION)
	assert_str((await SaveService.save_slot(1, h.session)).error).is_equal(SaveService.REFUSED)
	assert_bool((await SaveService.save_slot(0, h.session, true)).ok).is_true()
	PauseManager.release_pause(PauseManager.TRANSITION)


func test_b12_autosave_content_after_exhaustion() -> void:
	GameClock.model.set_time(5, 14 * 60)
	var woke := [0]
	EventBus.player_woke.connect(func(_r, _d): woke[0] += 1)
	h.session.stamina.spend(1000, &"test")
	var n := 0
	while woke[0] == 0 and n < 900:
		await get_tree().process_frame
		n += 1
	var text := FileAccess.get_file_as_string(SaveService.paths(0)["json"])
	var r := SaveCodec.decode(text)
	assert_bool(r["ok"]).is_true()
	var d: Dictionary = r["data"]
	assert_int(d["player"]["stamina"]).is_equal(h.session.stamina.model.max_value())
	assert_bool((d["mail"]["inbox"] as Array).any(func(m): return m["kind"] == "CARE_PACKAGE")).is_true()
	assert_int(d["exhaustion"]["last_snack_day"]).is_equal(6)
	for path in ["clock/day", "player/stamina", "exhaustion/last_snack_day", "wallet/coins"]:
		assert_int(typeof(SaveCodec._path_get(d, path))).is_equal(TYPE_INT)
