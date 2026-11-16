## Rebind capture (spec 2.5, 5.8): the next key, mouse or pad button press becomes the
## binding for args.action on that device kind. Conflicts in a shared context and
## unbinding a locked gamepad action are refused. Hold ui_cancel 1 s to abort.
extends MenuBase

const ABORT_HOLD := 1.0

var action: StringName
var _hold := 0.0
var label: Label


func build() -> void:
	action = StringName(args.get("action", ""))
	make_list("Press a button for %s" % action, Vector2(520, 220))
	label = Label.new()
	label.text = "(hold Back / Esc to cancel)"
	list.add_child(label)


func _process(delta: float) -> void:
	if Input.is_action_pressed(&"ui_cancel"):
		_hold += delta
		if _hold >= ABORT_HOLD:
			close(&"aborted")
	else:
		_hold = 0.0


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton):
		return
	if not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var r := apply_event(event)
	if r.ok:
		close(&"ok")
	else:
		say("Cannot use that: %s" % r.error)


func on_cancel() -> void:
	pass   # B may be the button being bound; abort is the 1 s hold


## Current bindings of every action as plain dictionaries (defaults plus saved rebinds).
static func current_definitions() -> Dictionary:
	var defs := InputBindings.definitions()
	var rebinds: Dictionary = Settings.get_value("input", "rebinds")
	for a in rebinds:
		if defs.has(StringName(a)):
			defs[StringName(a)]["events"] = rebinds[a]
	return defs


## Replaces the action's binding for the event's device kind. Persists to settings.cfg.
func apply_event(event: InputEvent) -> Result:
	var d := RebindModel.dict_from_event(event)
	if d.is_empty():
		return Result.failure(&"invalid_event")
	var defs := current_definitions()
	if not defs.has(action):
		return Result.failure(&"unknown_action")
	var pad := RebindModel.is_gamepad(d)
	var events: Array = (defs[action]["events"] as Array).filter(func(e): return RebindModel.is_gamepad(e) != pad)
	events.append(d)
	var check := RebindModel.validate_rebind(action, events, defs)
	if not check.ok:
		return check
	var rebinds: Dictionary = (Settings.get_value("input", "rebinds") as Dictionary).duplicate(true)
	rebinds[String(action)] = events
	Settings.set_value("input", "rebinds", rebinds)
	InputService.apply_rebinds({action: events})
	Settings.save_to()
	return Result.success(events)
