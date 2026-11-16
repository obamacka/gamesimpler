## One physics tick of gameplay input (spec 2.1). Produced only by InputReader,
## consumed by the player FSM. Tests build frames directly.
class_name InputFrame
extends RefCounted

var move := Vector2.ZERO        # x right, y forward-negative (stick convention)
var look := Vector2.ZERO        # right stick, -1..1
var look_mouse := Vector2.ZERO  # mouse motion delta in pixels since last frame
var run_pressed := false
var run_held := false
var jump_pressed := false
var jump_held := false
var duck_pressed := false
var duck_held := false
var interact_pressed := false
var interact_alt_pressed := false
var use_pressed := false
var use_held := false
var use_released := false
var alt_pressed := false
var alt_held := false
var build_toggle_pressed := false
var rotate_cw_pressed := false
var rotate_ccw_pressed := false
var build_tool_next_pressed := false
var build_tool_prev_pressed := false
var hotbar_next_pressed := false
var hotbar_prev_pressed := false
var hotbar_select := -1
var catalog_pressed := false
var undo_pressed := false
var wheel_pressed := false
var pet_call_pressed := false
var quick_eat_pressed := false
var camera_reset_pressed := false
var notes_pressed := 0          # bit i set = note_(i+1) pressed
var frame := 0


func duplicate_frame() -> InputFrame:
	var f := InputFrame.new()
	for p in get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			f.set(p["name"], get(p["name"]))
	return f


## Copy with every *_pressed / *_released edge cleared (held state and axes kept).
func held_only() -> InputFrame:
	var f := duplicate_frame()
	for p in get_property_list():
		var n: String = p["name"]
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and (n.ends_with("_pressed") or n.ends_with("_released")):
			f.set(n, false)
	f.notes_pressed = 0
	f.hotbar_select = -1
	f.look_mouse = Vector2.ZERO
	return f
