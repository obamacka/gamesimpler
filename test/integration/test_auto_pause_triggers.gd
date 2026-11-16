# P4.18: focus loss and pad loss (spec 5.6).
extends GdUnitTestSuite

var h: Phase2Harness


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")


func after_test() -> void:
	InputService.device = InputDeviceModel.new()
	h.stop()
	await get_tree().process_frame


func test_focus_out_opens_pause_menu() -> void:
	h.menus._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_str(h.menus.top().menu_id).is_equal(&"pause_menu")
	assert_bool(get_tree().paused).is_true()
	h.menus._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_int(h.menus.depth()).is_equal(1)   # not stacked twice


func test_pad_loss_pauses_with_banner_and_reconnect_releases() -> void:
	var b := InputEventJoypadButton.new()
	b.device = 0
	b.button_index = JOY_BUTTON_A
	b.pressed = true
	InputService.handle_event(b)
	assert_int(InputService.device.kind).is_equal(InputDeviceModel.DeviceKind.GAMEPAD)
	InputService._on_joy_connection_changed(0, false)
	assert_bool(PauseManager.has_reason(PauseManager.DEVICE_LOST)).is_true()
	assert_bool(h.menus.banner.visible).is_true()
	assert_str(h.menus.top().menu_id).is_equal(&"pause_menu")
	InputService._on_joy_connection_changed(0, true)
	assert_bool(PauseManager.has_reason(PauseManager.DEVICE_LOST)).is_false()
	assert_bool(h.menus.banner.visible).is_false()
	assert_bool(get_tree().paused).is_true()   # the pause menu stays until closed
	h.menus.close_all()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(get_tree().paused).is_false()
