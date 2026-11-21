## Accessibility and settings runtime (spec 5.10, P4.12): text scale on the root theme,
## palette and reduce-motion queries, prompt labels, TTS through DisplayServer when enabled
## (D14), and the Audio (master volume) and Video (fullscreen, vsync) options.
class_name Accessibility
extends Node

static var last_spoken := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply()
	apply_audio_video()
	EventBus.settings_changed.connect(_on_settings)


func _exit_tree() -> void:
	if EventBus.settings_changed.is_connected(_on_settings):
		EventBus.settings_changed.disconnect(_on_settings)


func _on_settings(section: StringName, _k: StringName, _v: Variant) -> void:
	if section == &"accessibility":
		apply()
	elif section == &"audio" or section == &"video":
		apply_audio_video()


## Picture-first theme (spec 12.4) with the text scale applied. Menus, the title and the HUD
## live in CanvasLayers, which the root window's theme does not reach, so the theme is merged
## into the engine default theme that every Control falls back to; the root keeps a copy.
func apply() -> void:
	var t := KidTheme.build(text_scale())
	ThemeDB.get_default_theme().merge_with(t)
	ThemeDB.get_default_theme().default_font_size = t.default_font_size
	ThemeDB.get_default_theme().default_font = t.default_font
	get_tree().root.theme = t


func apply_audio_video() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(Settings.get_value("audio", "master")))))
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(Settings.get_value("video", "fullscreen")) else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(Settings.get_value("video", "vsync")) else DisplayServer.VSYNC_DISABLED)


static func text_scale() -> float:
	return float(Settings.get_value("accessibility", "text_scale"))


static func reduce_motion() -> bool:
	return bool(Settings.get_value("accessibility", "reduce_motion"))


static func palette() -> StringName:
	return StringName(Settings.get_value("accessibility", "color_palette"))


static func prompt_labels() -> bool:
	return bool(Settings.get_value("accessibility", "prompt_labels"))


## Speaks `text` with an OS voice when TTS is enabled. Returns true if a voice was asked.
static func speak(text: String) -> bool:
	if text == "" or not bool(Settings.get_value("accessibility", "tts_enabled")):
		return false
	last_spoken = text
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return false
	var voices := DisplayServer.tts_get_voices_for_language(TranslationServer.get_locale().substr(0, 2))
	if voices.is_empty():
		return false
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, voices[0], 50, 1.0, float(Settings.get_value("accessibility", "tts_rate")))
	return true
