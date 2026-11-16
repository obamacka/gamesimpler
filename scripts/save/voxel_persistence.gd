## Voxel DB working copies and slot directories (spec 9.6). Overworld zones stream from
## SQLite files in a working directory; saving copies them into the slot with an epoch file.
class_name VoxelPersistence
extends RefCounted

const EPOCH_FILE := "voxels.epoch"
const TIMEOUT_MS := 10000


static func ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)


static func clear_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		clear_dir(path.path_join(sub))
		d.remove(sub)


static func remove_dir(path: String) -> void:
	if DirAccess.dir_exists_absolute(path):
		clear_dir(path)
		DirAccess.remove_absolute(path)


static func copy_dir(from: String, to: String) -> void:
	ensure_dir(to)
	var d := DirAccess.open(from)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.copy_absolute(from.path_join(f), to.path_join(f))


static func read_epoch(dir: String) -> int:
	var p := dir.path_join(EPOCH_FILE)
	if not FileAccess.file_exists(p):
		return 0   # no voxel dir yet (or a save from before voxel persistence): epoch 0
	return int(FileAccess.get_file_as_string(p).strip_edges())


static func write_epoch(dir: String, epoch: int) -> void:
	ensure_dir(dir)
	var f := FileAccess.open(dir.path_join(EPOCH_FILE), FileAccess.WRITE)
	f.store_string(str(epoch))
	f.close()


## Flushes the loaded terrain's modified blocks into its working DB. Returns false on abort
## or timeout (the save then writes nothing).
static func flush(zone: Node) -> bool:
	if zone == null or not (zone is Zone) or not (zone.terrain_node is VoxelTerrain):
		return true
	var t: VoxelTerrain = zone.terrain_node
	if t.stream == null:
		return true
	var tracker := t.save_modified_blocks()
	var start := Time.get_ticks_msec()
	while not tracker.is_complete():
		if tracker.is_aborted() or Time.get_ticks_msec() - start > TIMEOUT_MS:
			return false
		await zone.get_tree().process_frame
	return true
