## Save and load (spec 3.5, 9.6, P6.8, P6.9). Slots 1 to 3 are manual, slot 0 is the autosave
## written after every sleep. Layout under base_dir:
##   slot_<n>.json (+ .bak, .tmp)          the SaveCodec JSON, with voxel.epoch
##   slot_<n>.voxels/ (+ .bak/, .tmp/)     copies of the zone SQLite DBs and voxels.epoch
##   work/                                 the working DBs the loaded terrains stream from
## Order (spec 9.6): flush terrain, write voxel tmp dir, write JSON tmp, rotate JSON, rotate
## voxel dir. A crash between the JSON and voxel renames leaves new JSON with the old voxels;
## load then picks the newest consistent pair.
extends Node

const AUTOSAVE_SLOT := 0
const SLOTS := [1, 2, 3]
const REFUSED := &"refused_during_transition"
const VOXEL_FLUSH_FAILED := &"voxel_flush_failed"
const NO_SAVE := &"no_save"

var base_dir := "user://saves"
var enabled := true
var crash_after: StringName = &""   # test seam: stop right after this step
var autosave_count := 0
var last_snapshot: Dictionary = {}
var last_notices: Array = []
var busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func work_dir() -> String:
	return base_dir.path_join("work")


func paths(slot: int) -> Dictionary:
	var b := base_dir.path_join("slot_%d" % slot)
	return {"json": b + ".json", "bak": b + ".json.bak", "tmp": b + ".json.tmp",
		"vox": b + ".voxels", "vox_bak": b + ".voxels.bak", "vox_tmp": b + ".voxels.tmp"}


## A fresh game streams from an empty working directory.
func begin_new_game() -> void:
	VoxelPersistence.ensure_dir(work_dir())
	VoxelPersistence.clear_dir(work_dir())


func has_save(slot: int) -> bool:
	var p := paths(slot)
	return FileAccess.file_exists(p["json"]) or FileAccess.file_exists(p["bak"])


## Newest manual or autosave slot by file time, or -1 (title Play, spec 12.1).
func latest_slot() -> int:
	var best := -1
	var best_t := -1
	for slot in [AUTOSAVE_SLOT] + SLOTS:
		var p := paths(slot)
		for k in ["json", "bak"]:
			if FileAccess.file_exists(p[k]):
				var t := FileAccess.get_modified_time(p[k])
				if t > best_t:
					best_t = t
					best = slot
	return best


## Small summary for the save/load menu: {"exists", "day", "coins"}.
func slot_info(slot: int) -> Dictionary:
	var r := _read_json(paths(slot)["json"])
	if not r["ok"]:
		r = _read_json(paths(slot)["bak"])
	if not r["ok"]:
		return {"exists": false}
	var d: Dictionary = r["data"]
	return {"exists": true, "day": int(d.get("clock", {}).get("day", 1)), "coins": int(d.get("wallet", {}).get("coins", 0))}


## Phase 2 contract kept: SleepDirector calls this at its defined point (spec 6.2).
func autosave(session: GameSession) -> void:
	autosave_count += 1
	last_snapshot = session.to_dict().duplicate(true)
	if enabled:
		await save_slot(AUTOSAVE_SLOT, session, true)


func save_slot(slot: int, session: GameSession, allow_transition: bool = false) -> Result:
	if PauseManager.has_reason(PauseManager.TRANSITION) and not allow_transition:
		return Result.failure(REFUSED)
	if busy:
		return Result.failure(&"busy")
	busy = true
	var r: Result = await _save(slot, session)
	busy = false
	if r.ok:
		EventBus.game_saved.emit(slot)
	else:
		EventBus.save_failed.emit(slot, r.error)
	return r


func _save(slot: int, session: GameSession) -> Result:
	VoxelPersistence.ensure_dir(base_dir)
	VoxelPersistence.ensure_dir(work_dir())
	if not await VoxelPersistence.flush(SceneRouter.current_zone):
		return Result.failure(VOXEL_FLUSH_FAILED)
	var p := paths(slot)
	var epoch := maxi(VoxelPersistence.read_epoch(p["vox"]), VoxelPersistence.read_epoch(p["vox_bak"])) + 1
	VoxelPersistence.remove_dir(p["vox_tmp"])
	VoxelPersistence.copy_dir(work_dir(), p["vox_tmp"])
	VoxelPersistence.write_epoch(p["vox_tmp"], epoch)
	if crash_after == &"voxel_tmp":
		return Result.failure(&"crashed")
	var d := session.to_dict()
	d["voxel"] = {"epoch": epoch}
	var f := FileAccess.open(p["tmp"], FileAccess.WRITE)
	if f == null:
		return Result.failure(&"write_failed")
	f.store_string(SaveCodec.encode(d))
	f.close()
	if crash_after == &"json_tmp":
		return Result.failure(&"crashed")
	if FileAccess.file_exists(p["json"]):
		if FileAccess.file_exists(p["bak"]):
			DirAccess.remove_absolute(p["bak"])
		DirAccess.rename_absolute(p["json"], p["bak"])
	DirAccess.rename_absolute(p["tmp"], p["json"])
	if crash_after == &"json_rename":
		return Result.failure(&"crashed")
	if DirAccess.dir_exists_absolute(p["vox"]):
		VoxelPersistence.remove_dir(p["vox_bak"])
		DirAccess.rename_absolute(p["vox"], p["vox_bak"])
	DirAccess.rename_absolute(p["vox_tmp"], p["vox"])
	return Result.success(epoch)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": NO_SAVE, "data": {}, "notices": []}
	return SaveCodec.decode(FileAccess.get_file_as_string(path))


## Reads a slot: primary JSON, else .bak; then the newest voxel dir whose epoch matches the
## chosen JSON. Copies those DBs into the working directory. Returns data and notices.
func load_slot(slot: int) -> Result:
	var p := paths(slot)
	var notices: Array = []
	var candidates: Array = []
	for key in ["json", "bak"]:
		var r := _read_json(p[key])
		if r["ok"]:
			candidates.append({"key": key, "data": r["data"], "notices": r["notices"]})
		elif key == "json" and FileAccess.file_exists(p["json"]):
			notices.append(&"backup_used")
	if candidates.is_empty():
		return Result.failure(NO_SAVE)
	for c in candidates:
		var epoch := int(c["data"].get("voxel", {}).get("epoch", 0))
		for vkey in ["vox", "vox_bak"]:
			if VoxelPersistence.read_epoch(p[vkey]) == epoch:
				if c["key"] == "bak" and not (&"backup_used" in notices):
					notices.append(&"backup_used")
				if vkey == "vox_bak":
					notices.append(&"voxel_backup_used")
				notices.append_array(c["notices"])
				VoxelPersistence.ensure_dir(work_dir())
				VoxelPersistence.clear_dir(work_dir())
				VoxelPersistence.copy_dir(p[vkey], work_dir())
				DirAccess.remove_absolute(work_dir().path_join(VoxelPersistence.EPOCH_FILE))
				last_notices = notices
				return Result.success({"data": c["data"], "notices": notices, "used": c["key"]})
	return Result.failure(&"no_consistent_pair")


## Loads a slot into `session` and moves the player to the saved place (game code path).
func load_into(slot: int, session: GameSession) -> Result:
	var r := load_slot(slot)
	if not r.ok:
		return r
	var d: Dictionary = r.data["data"]
	session.from_dict(d)
	var pl: Dictionary = d.get("player", {})
	var zone := StringName(pl.get("zone_id", String(session.housing.home_zone)))
	await SceneRouter.change_zone(zone, session.housing.home_bed_key)
	var pos: Array = pl.get("position", [0, 0, 0])
	if is_instance_valid(session.player) and Database.zones.has(zone):
		session.player.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	EventBus.game_loaded.emit(slot, r.data["notices"])
	return r


func delete_slot(slot: int) -> void:
	var p := paths(slot)
	for k in ["json", "bak", "tmp"]:
		if FileAccess.file_exists(p[k]):
			DirAccess.remove_absolute(p[k])
	for k in ["vox", "vox_bak", "vox_tmp"]:
		VoxelPersistence.remove_dir(p[k])
