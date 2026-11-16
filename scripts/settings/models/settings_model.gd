## Player settings with defaults (spec 3.8, 5.10). Pure data; the Settings autoload
## handles the ConfigFile. Later phases add keys to DEFAULTS.
class_name SettingsModel
extends RefCounted

const DEFAULTS := {
	"input": {
		"run_mode": "toggle",
		"duck_mode": "toggle",
		"jump_auto": true,
		"sensitivity": 1.0,
		"invert_y": false,
		"glyph_override": -1,
		"rebinds": {},
	},
	"assist": {
		"auto_tool": true,
		"auto_tool_revert": false,
		"go_home_confirm": true,
		"snap_strength": "high",
		"fasten_mode": "press",
		"remove_hold_sec": 0.6,
	},
	"accessibility": {
		"color_palette": "DEFAULT",
		"prompt_labels": true,
		"text_scale": 1.25,
		"reduce_motion": false,
		"tts_enabled": false,
	},
}

var _data: Dictionary = DEFAULTS.duplicate(true)


func get_value(section: String, key: String) -> Variant:
	return _data[section][key]


## Returns false (and changes nothing) for unknown keys or a value of the wrong type.
func set_value(section: String, key: String, value: Variant) -> bool:
	if not DEFAULTS.has(section) or not DEFAULTS[section].has(key):
		return false
	if not _type_matches(DEFAULTS[section][key], value):
		return false
	_data[section][key] = value
	return true


func to_dict() -> Dictionary:
	return _data.duplicate(true)


## Loads known keys from `d`; unknown sections/keys and wrongly typed values are ignored
## and keep their defaults.
func from_dict(d: Dictionary) -> void:
	_data = DEFAULTS.duplicate(true)
	for section in d:
		if not (d[section] is Dictionary):
			continue
		for key in d[section]:
			set_value(String(section), String(key), d[section][key])


func reset() -> void:
	_data = DEFAULTS.duplicate(true)


static func _type_matches(default_value: Variant, value: Variant) -> bool:
	var dt := typeof(default_value)
	var vt := typeof(value)
	if dt == TYPE_FLOAT and vt == TYPE_INT:
		return true
	return dt == vt
