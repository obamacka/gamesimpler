## Writes InputBindings.definitions() into project.godot's [input] section.
## Run after editing scripts/input/input_bindings.gd:
##   godot --headless --path . -s res://scripts/tools/generate_input_map.gd
extends SceneTree


func _initialize() -> void:
	var defs := InputBindings.definitions()
	for action in defs:
		var events: Array = []
		for ev in defs[action]["events"]:
			events.append(RebindModel.event_from_dict(ev))
		ProjectSettings.set_setting("input/%s" % action, {
			"deadzone": defs[action]["deadzone"],
			"events": events,
		})
	var err := ProjectSettings.save()
	print("generate_input_map: wrote %d actions (%s)" % [defs.size(), error_string(err)])
	quit(0 if err == OK else 1)
