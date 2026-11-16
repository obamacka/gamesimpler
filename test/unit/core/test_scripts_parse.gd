# Every GDScript under scripts/, ui/ and scenes/ compiles (warnings are errors in this
# project). Catches scripts no other test loads, such as UI that only the main scene uses.
extends GdUnitTestSuite


func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_collect(dir.path_join(sub), out)


func test_all_scripts_compile() -> void:
	var files: Array[String] = []
	for root in ["res://scripts", "res://ui", "res://scenes", "res://spikes"]:
		_collect(root, files)
	assert_int(files.size()).is_greater(50)
	var failed: Array[String] = []
	for f in files:
		var s := ResourceLoader.load(f, "GDScript") as GDScript
		if s == null or not s.can_instantiate():
			failed.append(f)
	assert_array(failed).is_empty()


func _collect_ext(dir: String, ext: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_collect_ext(dir.path_join(sub), ext, out)


func test_all_scenes_load() -> void:
	var files: Array[String] = []
	for root in ["res://scenes", "res://ui", "res://test/integration/scenes"]:
		_collect_ext(root, ".tscn", files)
	assert_int(files.size()).is_greater(8)
	var failed: Array[String] = []
	for f in files:
		if ResourceLoader.load(f, "PackedScene") == null:
			failed.append(f)
	assert_array(failed).is_empty()
