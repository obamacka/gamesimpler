## Settings (spec 5.8, 5.10): Controls (rebinding), Assist, Accessibility, Audio, Video.
## Every change goes through set_option, which saves settings.cfg.
extends MenuBase

const CHOICES := {
	"input/run_mode": ["toggle", "hold"], "input/duck_mode": ["toggle", "hold"],
	"assist/snap_strength": ["low", "normal", "high"], "assist/fasten_mode": ["press", "hold"],
	"accessibility/color_palette": ["DEFAULT", "BLUE_ORANGE", "HIGH_CONTRAST"],
	"accessibility/text_scale": [1.0, 1.25, 1.5],
	"assist/remove_hold_sec": [0.4, 0.6, 0.8, 1.0, 1.5],
}
const PAGES := {
	"Assist": ["assist/auto_tool", "assist/auto_tool_revert", "assist/go_home_confirm", "assist/snap_strength",
		"assist/fasten_mode", "assist/remove_hold_sec", "input/jump_auto", "input/run_mode", "input/duck_mode", "input/invert_y"],
	"Accessibility": ["accessibility/color_palette", "accessibility/prompt_labels", "accessibility/text_scale",
		"accessibility/reduce_motion", "accessibility/tts_enabled"],
	"Audio": ["audio/master", "audio/music", "audio/effects"],
	"Video": ["video/fullscreen", "video/vsync"],
}

var tabs: TabContainer
var rows: Dictionary = {}   # "section/key" -> Button


func build() -> void:
	var p := MenuBase.panel(Vector2(760, 520))
	add_child(p)
	tabs = TabContainer.new()
	p.add_child(tabs)
	var controls := _page("Controls")
	for action in InputBindings.definitions():
		if String(action).begins_with("ui_") or String(action).begins_with("debug"):
			continue
		var a := StringName(action)
		add_row("%s: %s" % [action, _binding_text(a)], Color(0.6, 0.7, 0.9), func(): rebind(a), true, controls)
	for page in PAGES:
		var v := _page(page)
		for path in PAGES[page]:
			var parts: PackedStringArray = path.split("/")
			var key := String(path)
			rows[key] = add_row(_label(parts[0], parts[1]), Color(0.7, 0.8, 0.6), func(): cycle(parts[0], parts[1]), true, v)


func _page(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.follow_focus = true
	tabs.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v


func initial_focus() -> Control:
	return first_enabled(tabs.get_child(0).get_child(0))


func _label(section: String, key: String) -> String:
	return "%s: %s" % [key, str(Settings.get_value(section, key))]


func _binding_text(action: StringName) -> String:
	return ", ".join(InputMap.action_get_events(action).map(func(e): return e.as_text()))


## Changes one option and persists settings.cfg. Returns false for an invalid value.
func set_option(section: String, key: String, value: Variant) -> bool:
	if not Settings.set_value(section, key, value):
		return false
	Settings.save_to()
	var b: Button = rows.get("%s/%s" % [section, key])
	if b:
		b.text = _label(section, key)
	return true


## Booleans toggle; listed choices advance; volumes step by 0.25.
func cycle(section: String, key: String) -> void:
	var cur = Settings.get_value(section, key)
	var path := "%s/%s" % [section, key]
	if cur is bool:
		set_option(section, key, not cur)
	elif CHOICES.has(path):
		var c: Array = CHOICES[path]
		set_option(section, key, c[(c.find(cur) + 1) % c.size()])
	elif cur is float:
		set_option(section, key, 0.0 if cur >= 1.0 else minf(1.0, cur + 0.25))


func rebind(action: StringName) -> void:
	MenuStack.instance.push(&"rebind_capture", {"action": action})
