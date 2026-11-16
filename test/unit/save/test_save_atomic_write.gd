# P6.13: a crash between any two save steps leaves a loadable primary or .bak.
extends GdUnitTestSuite

const DIR := "user://test_tmp/atomic"

var s: GameSession


func before_test() -> void:
	SaveService.base_dir = DIR
	VoxelPersistence.remove_dir(DIR)
	s = GameSession.create(9)
	add_child(s)
	s.new_game()


func after_test() -> void:
	SaveService.crash_after = &""
	VoxelPersistence.remove_dir(DIR)
	SaveService.base_dir = "user://test_tmp/saves"
	s.queue_free()


func test_crash_at_each_step_keeps_a_consistent_state() -> void:
	s.wallet.model.coins = 111
	assert_bool((await SaveService.save_slot(1, s)).ok).is_true()
	for step in [&"voxel_tmp", &"json_tmp", &"json_rename"]:
		s.wallet.model.coins = 222
		SaveService.crash_after = step
		await SaveService.save_slot(1, s)
		SaveService.crash_after = &""
		var r := SaveService.load_slot(1)
		assert_bool(r.ok).override_failure_message("no loadable state after crash at %s" % step).is_true()
		var coins: int = r.data["data"]["wallet"]["coins"]
		assert_bool(coins in [111, 222]).is_true()
		var epoch := int(r.data["data"]["voxel"]["epoch"])
		assert_int(epoch).is_greater(0)
		# reset to a clean save before the next crash point
		assert_bool((await SaveService.save_slot(1, s)).ok).is_true()
		s.wallet.model.coins = 111
		assert_bool((await SaveService.save_slot(1, s)).ok).is_true()


func test_corrupt_primary_uses_backup() -> void:
	s.wallet.model.coins = 5
	await SaveService.save_slot(2, s)
	s.wallet.model.coins = 6
	await SaveService.save_slot(2, s)
	var f := FileAccess.open(SaveService.paths(2)["json"], FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	var r := SaveService.load_slot(2)
	assert_bool(r.ok).is_true()
	assert_int(r.data["data"]["wallet"]["coins"]).is_equal(5)
	assert_array(r.data["notices"]).contains([&"backup_used"])
