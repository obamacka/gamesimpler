## The only node that reads gameplay input (spec 2.1). Builds one InputFrame per physics
## tick from named actions, plus the mouse-motion delta (the one permitted raw event).
## Tests drive the player with inject_once()/inject_hold() instead of InputEvents.
class_name InputReader
extends Node

const PRESS_ACTIONS := {
	"run_pressed": &"run",
	"jump_pressed": &"jump",
	"duck_pressed": &"duck",
	"interact_pressed": &"interact",
	"interact_alt_pressed": &"interact_alt",
	"use_pressed": &"use_tool",
	"alt_pressed": &"use_alt",
	"build_toggle_pressed": &"build_mode",
	"rotate_cw_pressed": &"rotate_cw",
	"rotate_ccw_pressed": &"rotate_ccw",
	"build_tool_next_pressed": &"build_tool_next",
	"build_tool_prev_pressed": &"build_tool_prev",
	"hotbar_next_pressed": &"hotbar_next",
	"hotbar_prev_pressed": &"hotbar_prev",
	"catalog_pressed": &"build_catalog",
	"undo_pressed": &"undo",
	"wheel_pressed": &"emote_wheel",
	"pet_call_pressed": &"pet_call",
	"quick_eat_pressed": &"quick_eat",
	"camera_reset_pressed": &"camera_reset",
}

const HELD_ACTIONS := {
	"run_held": &"run",
	"jump_held": &"jump",
	"duck_held": &"duck",
	"use_held": &"use_tool",
	"alt_held": &"use_alt",
}

var guard := ResumeGuardModel.new()

var _queue: Array[InputFrame] = []
var _hold: InputFrame = null
var _mouse_delta := Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += event.relative


## Test seam: the next read returns `frame` once.
func inject_once(frame: InputFrame) -> void:
	_queue.append(frame)


## Test seam: every read returns the held part of `frame` (edges cleared) until cleared.
func inject_hold(frame: InputFrame) -> void:
	_hold = frame.held_only()


func clear_injection() -> void:
	_queue.clear()
	_hold = null


func is_injecting() -> bool:
	return not _queue.is_empty() or _hold != null


## Arms the resume guard (spec 5.5). Called when a menu closes or the player wakes.
func arm_resume_guard(frame: int) -> void:
	var held: Array = []
	for action in PRESS_ACTIONS.values():
		if Input.is_action_pressed(action):
			held.append(action)
	guard.arm(frame, held)


func read_frame() -> InputFrame:
	var frame_no := Engine.get_physics_frames()
	if not _queue.is_empty():
		var f: InputFrame = _queue.pop_front()
		f.frame = frame_no
		return f
	if _hold != null:
		var h := _hold.duplicate_frame()
		h.frame = frame_no
		return h
	return _poll(frame_no)


func _poll(frame_no: int) -> InputFrame:
	var f := InputFrame.new()
	f.frame = frame_no
	f.move = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	f.look = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	f.look_mouse = _mouse_delta
	_mouse_delta = Vector2.ZERO
	for field in PRESS_ACTIONS:
		var action: StringName = PRESS_ACTIONS[field]
		var exact := action in InputBindings.EXACT_MATCH
		var held := Input.is_action_pressed(action, exact)
		var pressed := Input.is_action_just_pressed(action, exact)
		f.set(field, guard.filter_pressed(action, frame_no, pressed, held))
	for field in HELD_ACTIONS:
		var action: StringName = HELD_ACTIONS[field]
		f.set(field, guard.filter_held(action, Input.is_action_pressed(action)))
	f.use_released = Input.is_action_just_released(&"use_tool")
	for i in range(1, 9):
		var a := StringName("hotbar_%d" % i)
		if guard.filter_pressed(a, frame_no, Input.is_action_just_pressed(a), Input.is_action_pressed(a)):
			f.hotbar_select = i - 1
			break
	for i in range(1, 9):
		var a := StringName("note_%d" % i)
		if guard.filter_pressed(a, frame_no, Input.is_action_just_pressed(a), Input.is_action_pressed(a)):
			f.notes_pressed |= 1 << (i - 1)
	return f
