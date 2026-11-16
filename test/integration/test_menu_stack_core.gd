# P3.20: MenuStack core (spec 5.3).
extends GdUnitTestSuite

var h: Phase2Harness
var _rec: SignalRecorder


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	BuildFixture.setup(h)
	h.session.inventory.add(&"item_piece_chair", 2)
	_rec = SignalRecorder.new(EventBus, [&"game_paused", &"game_resumed", &"menu_opened", &"menu_closed"])


func after_test() -> void:
	_rec.stop()
	h.stop()
	await get_tree().process_frame


func test_push_pauses_once_nested_until_last_pop() -> void:
	var m := h.menus
	var a := m.push(&"confirm", {"text": "a"})
	assert_object(a).is_not_null()
	assert_bool(get_tree().paused).is_true()
	assert_int(a.process_mode).is_equal(Node.PROCESS_MODE_WHEN_PAUSED)
	m.push(&"confirm", {"text": "b"})
	assert_int(_rec.count(&"game_paused")).is_equal(1)
	m.pop()
	await get_tree().process_frame
	assert_bool(get_tree().paused).is_true()
	m.pop()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(get_tree().paused).is_false()
	assert_int(_rec.count(&"game_resumed")).is_equal(1)
	assert_int(_rec.count(&"menu_closed")).is_equal(2)


func test_close_all() -> void:
	h.menus.push(&"confirm")
	h.menus.push(&"confirm")
	h.menus.push(&"confirm")
	h.menus.close_all()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(h.menus.is_open()).is_false()
	assert_bool(PauseManager.is_paused()).is_false()


func test_focus_initial_and_restored() -> void:
	var a: MenuBase = h.menus.push(&"confirm")
	await get_tree().process_frame
	assert_object(get_viewport().gui_get_focus_owner()).is_same(a.no)   # safe default
	a.yes.grab_focus()
	await get_tree().process_frame
	var b: MenuBase = h.menus.push(&"confirm", {"default_yes": true})
	await get_tree().process_frame
	assert_object(get_viewport().gui_get_focus_owner()).is_same(b.yes)
	h.menus.pop()
	await get_tree().process_frame
	assert_object(get_viewport().gui_get_focus_owner()).is_same(a.yes)


func test_push_refused_during_transition() -> void:
	PauseManager.request_pause(PauseManager.TRANSITION)
	assert_object(h.menus.push(&"confirm")).is_null()
	assert_bool(h.menus.is_open()).is_false()
	PauseManager.release_pause(PauseManager.TRANSITION)


func test_catalog_returns_to_same_build_substate() -> void:
	h.place(Vector3(-7.5, 0, 12.5))
	await h.frames(3)
	await BuildFixture.enter_build(h)
	var ctl := h.player.build_ctl
	ctl.model.next_tool()   # Paint
	h.press("catalog_pressed")
	await h.frames(2)
	assert_str(h.menus.top().menu_id).is_equal(&"build_catalog")
	assert_bool(get_tree().paused).is_true()
	h.menus.top().choose(&"piece", &"piece_chair")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(get_tree().paused).is_false()
	assert_str(ctl.model.tool).is_equal(BuildModel.PAINT)
	assert_str(ctl.model.sub).is_equal(BuildModel.PREVIEW)
	assert_str(ctl.model.selected["id"]).is_equal(&"piece_chair")
	assert_str(h.player.machine.current_id).is_equal(&"build")


func test_ui_cancel_pops() -> void:
	var a: MenuBase = h.menus.push(&"confirm")
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	h.menus._unhandled_input(ev)
	assert_bool(h.menus.is_open()).is_false()
	assert_str(a.result).is_equal(&"no")
