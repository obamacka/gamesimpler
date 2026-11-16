# P1.21: the glyph widget follows input_device_changed and always shows a label (K4).
extends GdUnitTestSuite

const Glyph := InputDeviceModel.GlyphSet
const ICON := preload("res://ui/prompts/glyph_icon.tscn")


func test_glyph_follows_device_changes() -> void:
	var icon: GlyphIcon = auto_free(ICON.instantiate())
	icon.button = &"face_left"
	add_child(icon)
	EventBus.input_device_changed.emit(InputDeviceModel.DeviceKind.GAMEPAD, Glyph.PLAYSTATION)
	assert_str(icon.label_text()).is_equal("Square")
	EventBus.input_device_changed.emit(InputDeviceModel.DeviceKind.GAMEPAD, Glyph.XBOX)
	assert_str(icon.label_text()).is_equal("X")
	assert_object(icon.color()).is_equal(Color(0.2, 0.45, 0.9, 1))
	EventBus.input_device_changed.emit(InputDeviceModel.DeviceKind.KEYBOARD_MOUSE, Glyph.KBM)
	assert_str(icon.label_text()).is_equal("E")


func test_every_glyph_set_labels_every_button() -> void:
	for gs in GlyphIcon.SETS:
		for b in [&"face_bottom", &"face_right", &"face_left", &"face_top", &"trigger_right", &"trigger_left", &"shoulder_right", &"shoulder_left"]:
			assert_bool((gs as GlyphSetDef).labels.has(b)).override_failure_message("%s missing %s" % [gs.id, b]).is_true()
			assert_bool((gs as GlyphSetDef).colors.has(b)).is_true()
