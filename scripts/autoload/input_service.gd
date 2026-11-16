## Input device tracking, glyph sets, joypad hotplug and rebinding (spec 2.5).
## The only non-UI code besides InputReader allowed to look at device-specific events.
extends Node

var device := InputDeviceModel.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	device.glyph_override = int(Settings.get_value("input", "glyph_override"))
	apply_rebinds(Settings.get_value("input", "rebinds"))
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	EventBus.settings_changed.connect(_on_settings_changed)


func _input(event: InputEvent) -> void:
	handle_event(event)


## Public so tests can feed constructed events (headless runs do not deliver InputEvents).
func handle_event(event: InputEvent) -> void:
	var vendor := 0
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		vendor = vendor_id(event.device)
	if device.feed(event, vendor):
		EventBus.input_device_changed.emit(device.kind, device.current_glyphs())


func current_glyphs() -> int:
	return device.current_glyphs()


func vendor_id(joy_device: int) -> int:
	var info := Input.get_joy_info(joy_device)
	return int(info.get("vendor_id", 0))


## Replaces each listed action's events with the given plain-dictionary events.
## Invalid entries are skipped with a warning; defaults stay for those actions.
func apply_rebinds(rebinds: Dictionary) -> void:
	var defs := InputBindings.definitions()
	for action in rebinds:
		var events: Array = rebinds[action]
		var check := RebindModel.validate_rebind(StringName(action), events, defs)
		if not check.ok:
			push_warning("InputService: ignoring rebind for %s (%s)" % [action, check.error])
			continue
		InputMap.action_erase_events(action)
		for ev in events:
			InputMap.action_add_event(action, RebindModel.event_from_dict(ev))
		defs[StringName(action)]["events"] = events


## Restores every action to the project defaults (generated from InputBindings).
func reset_to_defaults() -> void:
	InputMap.load_from_project_settings()


func _on_joy_connection_changed(joy_device: int, connected: bool) -> void:
	if connected:
		EventBus.joypad_restored.emit(joy_device)
	elif joy_device == device.active_joypad and device.kind == InputDeviceModel.DeviceKind.GAMEPAD:
		EventBus.joypad_lost.emit(joy_device)


func _on_settings_changed(section: StringName, key: StringName, value: Variant) -> void:
	if section == &"input" and key == &"glyph_override":
		device.glyph_override = int(value)
		EventBus.input_device_changed.emit(device.kind, device.current_glyphs())
