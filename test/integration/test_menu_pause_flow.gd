# P4.17: menus and the global pause (spec 5.2 to 5.5).
extends GdUnitTestSuite

var h: Phase2Harness
var _rec: SignalRecorder


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	h.world.fill(Vector3i(-16, -1, -8), Vector3i(16, -1, 16), h.vid(&"mat_grass"))
	_rec = SignalRecorder.new(EventBus, [&"game_paused", &"game_resumed", &"player_sent_home"])


func after_test() -> void:
	_rec.stop()
	h.stop()
	await get_tree().process_frame


func _action(name: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_every_menu_pauses_once_and_resumes_once() -> void:
	for id in [&"pause_menu", &"settings", &"inventory", &"shop", &"job_board", &"crafting", &"house_purchase", &"outfit_customizer", &"storage", &"confirm"]:
		_rec.clear()
		var m := h.menus.push(id, {"shop_id": &"shop_general", "station": &"WORKBENCH", "plot_id": &"plot_meadow_east", "uid": "p9999"})
		assert_object(m).override_failure_message("menu %s did not open" % id).is_not_null()
		assert_bool(get_tree().paused).is_true()
		assert_int(m.process_mode).is_equal(Node.PROCESS_MODE_WHEN_PAUSED)
		assert_int(_rec.count(&"game_paused")).is_equal(1)
		assert_array(m.focus_problems()).is_empty()
		h.menus.close_all()
		await _settle()
		assert_bool(get_tree().paused).override_failure_message("menu %s left the game paused" % id).is_false()
		assert_int(_rec.count(&"game_resumed")).is_equal(1)


func test_pause_menu_key_opens_and_closes_all() -> void:
	assert_bool(h.menus.handle_global(_action(&"pause_menu"))).is_true()
	assert_str(h.menus.top().menu_id).is_equal(&"pause_menu")
	h.menus.push(&"settings")
	assert_bool(h.menus.handle_global(_action(&"pause_menu"))).is_true()
	assert_bool(h.menus.is_open()).is_false()
	await _settle()
	assert_bool(PauseManager.is_paused()).is_false()


func test_ui_cancel_pops_and_inventory_key_toggles() -> void:
	assert_bool(h.menus.handle_global(_action(&"ui_cancel"))).is_false()   # ignored with no menu
	h.menus.handle_global(_action(&"open_inventory"))
	assert_str(h.menus.top().menu_id).is_equal(&"inventory")
	h.menus.push(&"confirm")
	h.menus.handle_global(_action(&"ui_cancel"))
	assert_str(h.menus.top().menu_id).is_equal(&"inventory")
	h.menus.handle_global(_action(&"open_inventory"))
	assert_bool(h.menus.is_open()).is_false()


func test_gameplay_frozen_while_menus_process() -> void:
	var hud := CanvasLayer.new()
	hud.set_script(load("res://ui/hud/hud.gd"))
	add_child(hud)
	h.menus.push(&"pause_menu")
	await _settle()
	assert_bool(hud.can_process()).is_false()
	assert_bool(h.player.can_process()).is_false()
	assert_bool(h.menus.top().can_process()).is_true()
	h.menus.close_all()
	await _settle()
	assert_bool(hud.can_process()).is_true()
	hud.queue_free()


func test_resume_guard_armed_on_close() -> void:
	h.menus.push(&"confirm")
	var frame := Engine.get_physics_frames()
	h.menus.pop()
	var g := h.player.input_reader.guard
	assert_int(g.resume_frame).is_greater_equal(frame)
	assert_bool(g.filter_pressed(&"jump", g.resume_frame, true, true)).is_false()   # the closing A press never jumps


func test_focus_restored_and_refused_during_transition() -> void:
	var a: MenuBase = h.menus.push(&"pause_menu")
	await _settle()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(a.resume_btn)
	h.menus.push(&"settings")
	await _settle()
	h.menus.pop()
	await _settle()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(a.resume_btn)
	h.menus.close_all()
	await _settle()
	PauseManager.request_pause(PauseManager.TRANSITION)
	assert_bool(h.menus.handle_global(_action(&"pause_menu"))).is_false()
	PauseManager.release_pause(PauseManager.TRANSITION)


func test_focus_recovery_when_lost() -> void:
	var a: MenuBase = h.menus.push(&"pause_menu")
	await _settle()
	get_viewport().gui_release_focus()
	await _settle()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(a.resume_btn)


func test_go_home_from_pause_menu() -> void:
	Settings.set_value("assist", "go_home_confirm", true)
	h.place(Vector3(8.5, 0, 12.5))
	var m: MenuBase = h.menus.push(&"pause_menu")
	m.go_home()
	assert_str(h.menus.top().menu_id).is_equal(&"go_home_confirm")
	assert_object(get_viewport().gui_get_focus_owner()).is_null()   # focus is deferred
	h.menus.top().close(&"yes")
	var n := 0
	while _rec.count(&"player_sent_home") == 0 and n < 300:
		await get_tree().process_frame
		n += 1
	assert_int(_rec.count(&"player_sent_home")).is_equal(1)
	assert_str(SceneRouter.current_zone_id).is_equal(&"zone_starter_cabin")
	assert_bool(h.menus.is_open()).is_false()
