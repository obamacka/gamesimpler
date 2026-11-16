## Settings autoload: owns the SettingsModel and user://settings.cfg (spec 3.8).
extends Node

const DEFAULT_PATH := "user://settings.cfg"

var model := SettingsModel.new()
var path := DEFAULT_PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_from(path)


func get_value(section: String, key: String) -> Variant:
	return model.get_value(section, key)


func set_value(section: String, key: String, value: Variant) -> bool:
	if not model.set_value(section, key, value):
		return false
	EventBus.settings_changed.emit(StringName(section), StringName(key), value)
	return true


## Missing or unreadable files leave the defaults in place.
func load_from(file_path: String) -> void:
	path = file_path
	var cfg := ConfigFile.new()
	if cfg.load(file_path) != OK:
		model.reset()
		return
	var d := {}
	for section in cfg.get_sections():
		d[section] = {}
		for key in cfg.get_section_keys(section):
			d[section][key] = cfg.get_value(section, key)
	model.from_dict(d)


func save_to(file_path: String = "") -> Error:
	if file_path != "":
		path = file_path
	var cfg := ConfigFile.new()
	var d := model.to_dict()
	for section in d:
		for key in d[section]:
			cfg.set_value(section, key, d[section][key])
	return cfg.save(path)
