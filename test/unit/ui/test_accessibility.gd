# P4.12: accessibility runtime queries and TTS gating (D14: default off).
extends GdUnitTestSuite


func after_test() -> void:
	Settings.model.reset()
	Accessibility.last_spoken = ""


func test_tts_off_by_default_never_speaks() -> void:
	assert_bool(Accessibility.speak("Harvest")).is_false()
	assert_str(Accessibility.last_spoken).is_equal("")


func test_tts_on_records_text() -> void:
	Settings.set_value("accessibility", "tts_enabled", true)
	Accessibility.speak("Open mail")
	assert_str(Accessibility.last_spoken).is_equal("Open mail")   # headless has no voices; the request is still made


func test_queries_follow_settings() -> void:
	assert_float(Accessibility.text_scale()).is_equal(1.25)
	Settings.set_value("accessibility", "reduce_motion", true)
	Settings.set_value("accessibility", "color_palette", "HIGH_CONTRAST")
	assert_bool(Accessibility.reduce_motion()).is_true()
	assert_str(Accessibility.palette()).is_equal(&"HIGH_CONTRAST")


func test_text_scale_applies_to_root_theme() -> void:
	var a: Accessibility = auto_free(Accessibility.new())
	add_child(a)
	Settings.set_value("accessibility", "text_scale", 1.5)
	assert_int(get_tree().root.theme.default_font_size).is_equal(int(round(KidTheme.BASE_FONT * 1.5)))
	# the picture-first theme (spec 12.4): rounded buttons with a visible focus outline
	var focus := get_tree().root.theme.get_stylebox("focus", "Button") as StyleBoxFlat
	assert_that(focus.border_color).is_equal(KidTheme.FOCUS)
	assert_int(focus.border_width_top).is_greater_equal(6)
	Settings.set_value("accessibility", "text_scale", 1.25)
	get_tree().root.theme = null


func test_master_volume_applies() -> void:
	var a: Accessibility = auto_free(Accessibility.new())
	add_child(a)
	Settings.set_value("audio", "master", 0.5)
	assert_float(AudioServer.get_bus_volume_db(0)).is_equal_approx(linear_to_db(0.5), 0.01)
	Settings.set_value("audio", "master", 1.0)
	get_tree().root.theme = null
