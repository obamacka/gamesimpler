## One interaction a target offers (spec 4.5).
class_name InteractionSpec
extends RefCounted

var kind: StringName
var duration_sec := 0.0
var stamina_cost := 0
var handoff_state: StringName = &""   # &"sleep", &"talk", &"sit", &"craft" or empty
var prompt_icon: StringName = &""


func _init(k: StringName = &"", duration: float = 0.0, cost: int = 0, handoff: StringName = &"") -> void:
	kind = k
	duration_sec = duration
	stamina_cost = cost
	handoff_state = handoff
