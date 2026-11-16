## Single source of truth for the default input map (spec 2.2 to 2.4).
## scripts/tools/generate_input_map.gd writes these into project.godot; the unit suite
## test_input_action_map.gd fails if project.godot and this table drift apart.
## Event dictionaries use the RebindModel format.
class_name InputBindings
extends RefCounted

const GAMEPLAY := &"GAMEPLAY"
const AIRBORNE := &"AIRBORNE"
const BUILD := &"BUILD"
const INSTRUMENT := &"INSTRUMENT"
const UI := &"UI"
const CONTEXTS: Array[StringName] = [GAMEPLAY, AIRBORNE, BUILD, INSTRUMENT, UI]

const STICK_DEADZONE := 0.2
const LOOK_DEADZONE := 0.15
const TRIGGER_DEADZONE := 0.5
const UI_STICK_DEADZONE := 0.5
const BUTTON_DEADZONE := 0.5

## Actions that must keep at least one gamepad event (spec 2.5).
const LOCKED_GAMEPAD: Array[StringName] = [&"jump", &"pause_menu", &"ui_accept", &"ui_cancel"]

## Actions read with exact_match = true because another action in the same context
## uses the same key plus a modifier (Shift+R vs R).
const EXACT_MATCH: Array[StringName] = [&"rotate_cw", &"rotate_ccw"]

## Physical-input overlaps that are intentional despite sharing a context. Each entry is
## [action_a, action_b, rule]. Rules are enforced by the reader of the input.
const ALLOWED_OVERLAPS := [
	[&"pause_menu", &"ui_cancel", "Esc: in menus ui_cancel is handled first and marks the event handled (spec 5.3)"],
]


static func jb(button: int) -> Dictionary:
	return {"type": "joy_button", "button": button}


static func ja(axis: int, value: float) -> Dictionary:
	return {"type": "joy_axis", "axis": axis, "value": value}


static func key(code: int, shift: bool = false) -> Dictionary:
	var d := {"type": "key", "physical_keycode": code}
	if shift:
		d["shift"] = true
	return d


static func mb(button: int) -> Dictionary:
	return {"type": "mouse_button", "button": button}


static func _a(contexts: Array, events: Array, deadzone: float = BUTTON_DEADZONE) -> Dictionary:
	return {"contexts": contexts, "events": events, "deadzone": deadzone}


## action -> {"contexts": Array[StringName], "events": Array[Dictionary], "deadzone": float}
static func definitions() -> Dictionary:
	var G := GAMEPLAY
	var A := AIRBORNE
	var B := BUILD
	var I := INSTRUMENT
	var U := UI
	var d := {
		# Movement and camera (spec 2.2)
		&"move_left": _a([G, A, B], [ja(JOY_AXIS_LEFT_X, -1.0), key(KEY_A)], STICK_DEADZONE),
		&"move_right": _a([G, A, B], [ja(JOY_AXIS_LEFT_X, 1.0), key(KEY_D)], STICK_DEADZONE),
		&"move_forward": _a([G, A, B], [ja(JOY_AXIS_LEFT_Y, -1.0), key(KEY_W)], STICK_DEADZONE),
		&"move_back": _a([G, A, B], [ja(JOY_AXIS_LEFT_Y, 1.0), key(KEY_S)], STICK_DEADZONE),
		&"look_left": _a([G, A, B, I], [ja(JOY_AXIS_RIGHT_X, -1.0)], LOOK_DEADZONE),
		&"look_right": _a([G, A, B, I], [ja(JOY_AXIS_RIGHT_X, 1.0)], LOOK_DEADZONE),
		&"look_up": _a([G, A, B, I], [ja(JOY_AXIS_RIGHT_Y, -1.0)], LOOK_DEADZONE),
		&"look_down": _a([G, A, B, I], [ja(JOY_AXIS_RIGHT_Y, 1.0)], LOOK_DEADZONE),
		&"jump": _a([G, A, B], [jb(JOY_BUTTON_A), key(KEY_SPACE)]),
		&"duck": _a([G, B], [jb(JOY_BUTTON_B), key(KEY_C), key(KEY_CTRL)]),
		&"interact": _a([G, A, B], [jb(JOY_BUTTON_X), key(KEY_E)]),
		&"interact_alt": _a([G], [jb(JOY_BUTTON_Y), key(KEY_F)]),
		&"run": _a([G], [jb(JOY_BUTTON_LEFT_STICK), key(KEY_SHIFT)]),
		&"use_tool": _a([G, A, B], [ja(JOY_AXIS_TRIGGER_RIGHT, 1.0), mb(MOUSE_BUTTON_LEFT)], TRIGGER_DEADZONE),
		&"use_alt": _a([G, B], [ja(JOY_AXIS_TRIGGER_LEFT, 1.0), mb(MOUSE_BUTTON_RIGHT)], TRIGGER_DEADZONE),
		&"hotbar_next": _a([G], [jb(JOY_BUTTON_RIGHT_SHOULDER), mb(MOUSE_BUTTON_WHEEL_DOWN), key(KEY_BRACKETRIGHT)]),
		&"hotbar_prev": _a([G], [jb(JOY_BUTTON_LEFT_SHOULDER), mb(MOUSE_BUTTON_WHEEL_UP), key(KEY_BRACKETLEFT)]),
		&"build_mode": _a([G, B], [jb(JOY_BUTTON_DPAD_UP), key(KEY_B)]),
		&"emote_wheel": _a([G, I], [jb(JOY_BUTTON_DPAD_LEFT), key(KEY_G)]),
		&"pet_call": _a([G], [jb(JOY_BUTTON_DPAD_RIGHT), key(KEY_H)]),
		&"quick_eat": _a([G], [jb(JOY_BUTTON_DPAD_DOWN), key(KEY_Q)]),
		&"camera_reset": _a([G, A, B], [jb(JOY_BUTTON_RIGHT_STICK), mb(MOUSE_BUTTON_MIDDLE)]),
		&"open_inventory": _a([G, U], [jb(JOY_BUTTON_BACK), jb(JOY_BUTTON_TOUCHPAD), key(KEY_I)]),
		&"pause_menu": _a([G, A, B, I, U], [jb(JOY_BUTTON_START), key(KEY_ESCAPE)]),
		# Build context (spec 2.3)
		&"rotate_cw": _a([B], [jb(JOY_BUTTON_RIGHT_SHOULDER), key(KEY_R), mb(MOUSE_BUTTON_WHEEL_DOWN)]),
		&"rotate_ccw": _a([B], [jb(JOY_BUTTON_LEFT_SHOULDER), key(KEY_R, true), mb(MOUSE_BUTTON_WHEEL_UP)]),
		&"build_tool_next": _a([B], [jb(JOY_BUTTON_DPAD_RIGHT)]),
		&"build_tool_prev": _a([B], [jb(JOY_BUTTON_DPAD_LEFT)]),
		&"build_tool_place": _a([B], [key(KEY_1)]),
		&"build_tool_paint": _a([B], [key(KEY_2)]),
		&"build_tool_stamp": _a([B], [key(KEY_3)]),
		&"undo": _a([B], [jb(JOY_BUTTON_DPAD_DOWN), key(KEY_Z)]),
		&"build_catalog": _a([B], [jb(JOY_BUTTON_Y), key(KEY_F)]),
		# Instrument context (spec 2.3)
		&"note_1": _a([I], [jb(JOY_BUTTON_A), key(KEY_1)]),
		&"note_2": _a([I], [jb(JOY_BUTTON_B), key(KEY_2)]),
		&"note_3": _a([I], [jb(JOY_BUTTON_X), key(KEY_3)]),
		&"note_4": _a([I], [jb(JOY_BUTTON_Y), key(KEY_4)]),
		&"note_5": _a([I], [jb(JOY_BUTTON_LEFT_SHOULDER), key(KEY_5)]),
		&"note_6": _a([I], [jb(JOY_BUTTON_RIGHT_SHOULDER), key(KEY_6)]),
		&"note_7": _a([I], [ja(JOY_AXIS_TRIGGER_LEFT, 1.0), key(KEY_7)], TRIGGER_DEADZONE),
		&"note_8": _a([I], [ja(JOY_AXIS_TRIGGER_RIGHT, 1.0), key(KEY_8)], TRIGGER_DEADZONE),
		# UI (spec 2.4). Built-in ui_* actions are overridden with explicit events.
		&"ui_accept": _a([U], [jb(JOY_BUTTON_A), key(KEY_ENTER), key(KEY_KP_ENTER), key(KEY_SPACE)]),
		&"ui_cancel": _a([U], [jb(JOY_BUTTON_B), key(KEY_ESCAPE)]),
		&"ui_up": _a([U], [jb(JOY_BUTTON_DPAD_UP), ja(JOY_AXIS_LEFT_Y, -1.0), key(KEY_UP), key(KEY_W)], UI_STICK_DEADZONE),
		&"ui_down": _a([U], [jb(JOY_BUTTON_DPAD_DOWN), ja(JOY_AXIS_LEFT_Y, 1.0), key(KEY_DOWN), key(KEY_S)], UI_STICK_DEADZONE),
		&"ui_left": _a([U], [jb(JOY_BUTTON_DPAD_LEFT), ja(JOY_AXIS_LEFT_X, -1.0), key(KEY_LEFT), key(KEY_A)], UI_STICK_DEADZONE),
		&"ui_right": _a([U], [jb(JOY_BUTTON_DPAD_RIGHT), ja(JOY_AXIS_LEFT_X, 1.0), key(KEY_RIGHT), key(KEY_D)], UI_STICK_DEADZONE),
		&"ui_tab_next": _a([U], [jb(JOY_BUTTON_RIGHT_SHOULDER), key(KEY_E)]),
		&"ui_tab_prev": _a([U], [jb(JOY_BUTTON_LEFT_SHOULDER), key(KEY_Q)]),
		&"ui_page_next": _a([U], [ja(JOY_AXIS_TRIGGER_RIGHT, 1.0), key(KEY_PAGEDOWN)], TRIGGER_DEADZONE),
		&"ui_page_prev": _a([U], [ja(JOY_AXIS_TRIGGER_LEFT, 1.0), key(KEY_PAGEUP)], TRIGGER_DEADZONE),
		&"ui_secondary": _a([U], [jb(JOY_BUTTON_X), mb(MOUSE_BUTTON_RIGHT)]),
		&"ui_tertiary": _a([U], [jb(JOY_BUTTON_Y), key(KEY_R)]),
	}
	for i in range(1, 9):
		d[StringName("hotbar_%d" % i)] = _a([G], [key(KEY_0 + i)])
	return d

