# P3.21: Sit, toggle, bed confirm, Set Home (spec 4.5, 7.3).
extends GdUnitTestSuite

const CELL := Vector3i(-8, 0, 15)
const STAND := Vector3(-7.5, 0, 13.6)

var h: Phase2Harness
var _rec: SignalRecorder


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	BuildFixture.setup(h)
	_rec = SignalRecorder.new(EventBus, [&"furniture_toggled", &"sleep_transition_started", &"player_woke", &"home_changed", &"player_state_changed"])


func after_test() -> void:
	_rec.stop()
	h.stop()
	await get_tree().process_frame


func _put(piece: StringName) -> String:
	var uid := BuildFixture.place_fastened(h, piece, CELL, 0)
	h.place(STAND)
	h.aim_at_sky()
	await h.frames(4)
	return uid


func _await_woke(timeout_frames: int = 900) -> void:
	var n := 0
	while _rec.count(&"player_woke") == 0 and n < timeout_frames:
		await get_tree().process_frame
		n += 1
	await h.frames(2)


func _sit() -> PieceView:
	h.press("interact_pressed")
	var n := 0
	while h.player.machine.current_id != &"sit" and n < 60:
		await h.frames(1)
		n += 1
	return SceneRouter.current_zone.get_node("BuildView").views.values()[0]


func test_sit_snaps_regenerates_and_exits_without_jump() -> void:
	await _put(&"piece_chair")
	h.session.stamina.model.current = 50
	var view := await _sit()
	assert_str(h.player.machine.current_id).is_equal(&"sit")
	assert_vector(h.player.global_position).is_equal_approx(view.seats[0], Vector3.ONE * 0.01)
	await h.frames(130)   # 0.5 per second
	assert_int(h.session.stamina.model.current).is_equal(51)
	assert_vector(h.player.global_position).is_equal_approx(view.seats[0], Vector3.ONE * 0.01)
	h.press("jump_pressed")
	await h.frames(3)
	assert_str(h.player.machine.current_id).is_equal(&"idle")
	assert_float(h.player.velocity.y).is_less_equal(0.0)
	assert_vector(h.player.global_position).is_equal_approx(view.exits[0], Vector3(0.01, 0.2, 0.01))


func test_sit_exits_on_duck_and_on_move() -> void:
	await _put(&"piece_chair")
	await _sit()
	h.press("duck_pressed")
	await h.frames(4)
	assert_str(h.player.machine.current_id).is_equal(&"idle")   # B stands up; it does not also duck
	h.place(STAND)
	await h.frames(3)
	await _sit()
	h.hold({"move": Vector2(0, 1)})
	await h.frames(2)
	h.hold({})
	assert_bool(h.player.machine.current_id in [&"idle", &"walk"]).is_true()


func test_toggle_flips_and_persists() -> void:
	var uid := await _put(&"piece_lamp")
	h.press("interact_pressed")
	await h.frames(40)
	assert_int(_rec.count(&"furniture_toggled")).is_equal(1)
	assert_int(h.session.to_dict()["build"]["pieces"][uid]["toggle"]).is_equal(1)


func test_bed_confirm_runs_sleep_without_care_letter() -> void:
	await _put(&"piece_bed")
	h.press("interact_pressed")
	var n := 0
	while not h.menus.is_open() and n < 60:
		await h.frames(1)
		n += 1
	assert_str(h.menus.top().menu_id).is_equal(&"confirm")
	h.menus.top().close(&"yes")
	await _await_woke()
	var woke: Dictionary = _rec.records.filter(func(r): return r["name"] == &"player_woke")[0]
	assert_str(woke["args"][0]).is_equal(&"bed")
	assert_array(h.session.mail.model.inbox.filter(func(m): return m["kind"] == "CARE_PACKAGE")).is_empty()


func test_bed_no_keeps_playing() -> void:
	await _put(&"piece_bed")
	h.press("interact_pressed")
	await h.frames(30)
	h.menus.top().close(&"no")
	await h.frames(10)
	assert_int(_rec.count(&"sleep_transition_started")).is_equal(0)
	assert_str(h.player.machine.current_id).is_equal(&"idle")


func test_set_home_changes_wake_location() -> void:
	var uid := await _put(&"piece_bed")
	h.press("interact_alt_pressed")
	await h.frames(30)
	h.menus.top().close(&"yes")
	await h.frames(4)
	assert_str(h.session.housing.home_zone).is_equal(&"zone_home_meadow")
	assert_str(h.session.housing.home_bed_key).is_equal(StringName(uid))
	h.session.stamina.spend(1000, &"test")
	await _await_woke()
	assert_str(SceneRouter.current_zone_id).is_equal(&"zone_home_meadow")
	var bed_pos := Vector3(CELL) + Vector3(0.5, 0, 0.5)
	assert_float(Vector2(h.player.global_position.x, h.player.global_position.z).distance_to(Vector2(bed_pos.x, bed_pos.z))).is_less(0.1)
