## Resume input guard (spec 5.5). After a menu closes (or the player wakes), the button
## press that caused it must not also act in gameplay: press edges are dropped through
## `resume_frame`, and any action held at resume must be released before it counts again.
class_name ResumeGuardModel
extends RefCounted

var resume_frame := -1
var _needs_release: Dictionary = {}   # StringName -> true


## `held_actions`: actions physically held at the moment of resume.
func arm(frame: int, held_actions: Array) -> void:
	resume_frame = frame
	_needs_release.clear()
	for a in held_actions:
		_needs_release[a] = true


## Filters one action's press edge for physics frame `frame`. `held` is the raw held state.
func filter_pressed(action: StringName, frame: int, pressed: bool, held: bool) -> bool:
	if _needs_release.has(action):
		if not held:
			_needs_release.erase(action)
		return false
	if frame <= resume_frame:
		return false
	return pressed


## Held state is also suppressed until the action was released once.
func filter_held(action: StringName, held: bool) -> bool:
	if _needs_release.has(action):
		if not held:
			_needs_release.erase(action)
		return false
	return held


func is_armed() -> bool:
	return resume_frame >= 0 or not _needs_release.is_empty()
