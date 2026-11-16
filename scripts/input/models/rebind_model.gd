## Converts between plain-dictionary bindings and InputEvents, and validates rebinds
## (spec 2.5). Settings never store serialized InputEvent objects, only these dictionaries:
##   {"type": "joy_button", "button": int}
##   {"type": "joy_axis", "axis": int, "value": -1.0 | 1.0}
##   {"type": "key", "physical_keycode": int, "shift": bool (optional)}
##   {"type": "mouse_button", "button": int}
class_name RebindModel
extends RefCounted

## InputMap's "all devices" id for action events.
const ALL_DEVICES := -1


static func event_from_dict(d: Dictionary) -> InputEvent:
	match String(d.get("type", "")):
		"joy_button":
			var e := InputEventJoypadButton.new()
			e.button_index = int(d["button"]) as JoyButton
			e.device = ALL_DEVICES
			return e
		"joy_axis":
			var e := InputEventJoypadMotion.new()
			e.axis = int(d["axis"]) as JoyAxis
			e.axis_value = 1.0 if float(d["value"]) > 0.0 else -1.0
			e.device = ALL_DEVICES
			return e
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = int(d["physical_keycode"]) as Key
			e.shift_pressed = bool(d.get("shift", false))
			e.device = ALL_DEVICES
			return e
		"mouse_button":
			var e := InputEventMouseButton.new()
			e.button_index = int(d["button"]) as MouseButton
			e.device = ALL_DEVICES
			return e
	return null


static func dict_from_event(e: InputEvent) -> Dictionary:
	if e is InputEventJoypadButton:
		return {"type": "joy_button", "button": int(e.button_index)}
	if e is InputEventJoypadMotion:
		return {"type": "joy_axis", "axis": int(e.axis), "value": 1.0 if e.axis_value > 0.0 else -1.0}
	if e is InputEventKey:
		var code := int(e.physical_keycode) if e.physical_keycode != KEY_NONE else int(e.keycode)
		var d := {"type": "key", "physical_keycode": code}
		if e.shift_pressed:
			d["shift"] = true
		return d
	if e is InputEventMouseButton:
		return {"type": "mouse_button", "button": int(e.button_index)}
	return {}


static func is_gamepad(d: Dictionary) -> bool:
	var t := String(d.get("type", ""))
	return t == "joy_button" or t == "joy_axis"


## Canonical id of the physical input, including key modifiers and axis direction.
static func input_id(d: Dictionary) -> String:
	match String(d.get("type", "")):
		"joy_button":
			return "joy_button:%d" % int(d["button"])
		"joy_axis":
			return "joy_axis:%d:%s" % [int(d["axis"]), "+" if float(d["value"]) > 0.0 else "-"]
		"key":
			return "key:%d%s" % [int(d["physical_keycode"]), "+shift" if d.get("shift", false) else ""]
		"mouse_button":
			return "mouse_button:%d" % int(d["button"])
	return "unknown"


static func _overlap_allowed(a: StringName, b: StringName, allowed: Array) -> bool:
	for entry in allowed:
		if (entry[0] == a and entry[1] == b) or (entry[0] == b and entry[1] == a):
			return true
	return false


## Returns conflicts as [{"input": id, "actions": [a, b], "context": ctx}]: two actions that
## share a physical input and at least one context, excluding allowed overlaps.
static func find_conflicts(definitions: Dictionary, allowed: Array = InputBindings.ALLOWED_OVERLAPS) -> Array:
	var by_input := {}   # input id -> Array[StringName] actions
	for action in definitions:
		for ev in definitions[action]["events"]:
			var id := input_id(ev)
			if not by_input.has(id):
				by_input[id] = []
			if not by_input[id].has(action):
				by_input[id].append(action)
	var conflicts: Array = []
	for id in by_input:
		var actions: Array = by_input[id]
		for i in actions.size():
			for j in range(i + 1, actions.size()):
				var a: StringName = actions[i]
				var b: StringName = actions[j]
				if _overlap_allowed(a, b, allowed):
					continue
				for ctx in definitions[a]["contexts"]:
					if ctx in definitions[b]["contexts"]:
						conflicts.append({"input": id, "actions": [a, b], "context": ctx})
						break
	return conflicts


## Validates replacing `action`'s events with `events` against `definitions`.
## Fails with &"unknown_action", &"invalid_event", &"locked_gamepad" or &"conflict".
static func validate_rebind(action: StringName, events: Array, definitions: Dictionary) -> Result:
	if not definitions.has(action):
		return Result.failure(&"unknown_action")
	for ev in events:
		if event_from_dict(ev) == null:
			return Result.failure(&"invalid_event", ev)
	if action in InputBindings.LOCKED_GAMEPAD:
		var has_pad := false
		for ev in events:
			if is_gamepad(ev):
				has_pad = true
		if not has_pad:
			return Result.failure(&"locked_gamepad")
	var candidate := definitions.duplicate(true)
	candidate[action]["events"] = events.duplicate(true)
	var conflicts := find_conflicts(candidate)
	var mine: Array = []
	for c in conflicts:
		if action in c["actions"]:
			mine.append(c)
	if not mine.is_empty():
		return Result.failure(&"conflict", mine)
	return Result.success()
