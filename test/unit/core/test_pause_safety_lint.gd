# P1.24: pause-safety lint (spec 0.3, 5.7). Gameplay code must not create timers that keep
# running while paused, or unbound tweens.
extends GdUnitTestSuite

const ROOTS := ["res://scripts", "res://ui", "res://scenes"]


func _gd_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		_gd_files(dir_path.path_join(d), out)


func _scan(pattern: RegEx, allow: Callable) -> Array[String]:
	var files: Array[String] = []
	for root in ROOTS:
		_gd_files(root, files)
	var hits: Array[String] = []
	for path in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line := lines[i]
			if line.strip_edges().begins_with("#"):
				continue
			var m := pattern.search(line)
			if m and not allow.call(line, m):
				hits.append("%s:%d: %s" % [path, i + 1, line.strip_edges()])
	return hits


func test_create_timer_passes_process_always_false() -> void:
	var re := RegEx.create_from_string("create_timer\\(([^)]*)\\)")
	var hits := _scan(re, func(_line, m): return m.get_string(1).replace(" ", "").contains(",false"))
	assert_array(hits).override_failure_message("create_timer must pass process_always = false:\n%s" % "\n".join(hits)).is_empty()


func test_no_scene_tree_tweens() -> void:
	var re := RegEx.create_from_string("get_tree\\(\\)\\.create_tween\\(")
	var hits := _scan(re, func(_line, _m): return false)
	assert_array(hits).override_failure_message("use Node.create_tween():\n%s" % "\n".join(hits)).is_empty()


func test_lint_detects_violations() -> void:
	# Guard against a lint that silently matches nothing.
	var re := RegEx.create_from_string("create_timer\\(([^)]*)\\)")
	var bad := re.search("get_tree().create_timer(1.0)")
	assert_object(bad).is_not_null()
	assert_bool(bad.get_string(1).replace(" ", "").contains(",false")).is_false()
	assert_bool(re.search("get_tree().create_timer(1.0, false)").get_string(1).replace(" ", "").contains(",false")).is_true()
