# P6.13: JSON then DB ordering; an epoch mismatch picks the consistent pair; an aborted
# voxel flush writes nothing.
extends GdUnitTestSuite

const DIR := "user://test_tmp/epoch"

var s: GameSession


func before_test() -> void:
	SaveService.base_dir = DIR
	VoxelPersistence.remove_dir(DIR)
	SaveService.begin_new_game()
	s = GameSession.create(4)
	add_child(s)
	s.new_game()


func after_test() -> void:
	SaveService.crash_after = &""
	VoxelPersistence.remove_dir(DIR)
	SaveService.base_dir = "user://test_tmp/saves"
	s.queue_free()


func _write_work_db(text: String) -> void:
	var f := FileAccess.open(SaveService.work_dir().path_join("home_meadow.sqlite"), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_db_copied_with_matching_epoch() -> void:
	_write_work_db("v1")
	var r: Result = await SaveService.save_slot(1, s)
	var p := SaveService.paths(1)
	assert_int(VoxelPersistence.read_epoch(p["vox"])).is_equal(r.data)
	assert_str(FileAccess.get_file_as_string(p["vox"].path_join("home_meadow.sqlite"))).is_equal("v1")


func test_crash_between_json_and_db_uses_consistent_pair() -> void:
	_write_work_db("old")
	await SaveService.save_slot(1, s)
	_write_work_db("new")
	SaveService.crash_after = &"json_rename"   # new JSON, old voxel dir, new voxels only in .tmp
	await SaveService.save_slot(1, s)
	SaveService.crash_after = &""
	_write_work_db("garbage")
	var r := SaveService.load_slot(1)
	assert_bool(r.ok).is_true()
	assert_str(r.data["used"]).is_equal("bak")   # the .bak JSON matches the old voxel dir
	assert_str(FileAccess.get_file_as_string(SaveService.work_dir().path_join("home_meadow.sqlite"))).is_equal("old")


func test_flush_without_terrain_is_a_no_op() -> void:
	assert_bool(await VoxelPersistence.flush(null)).is_true()
	assert_bool(await VoxelPersistence.flush(auto_free(Node.new()))).is_true()
