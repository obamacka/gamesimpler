## Decor undo (spec 7.2, P6.7): ring buffer of the last 20 paint and stamp operations,
## cleared on zone change. Ops are plain dictionaries the BuildService knows how to revert.
class_name DecorUndoModel
extends RefCounted

const SIZE := 20

var ops: Array = []


func push(op: Dictionary) -> void:
	ops.append(op)
	while ops.size() > SIZE:
		ops.pop_front()


func pop() -> Dictionary:
	return ops.pop_back() if not ops.is_empty() else {}


func clear() -> void:
	ops.clear()


func size() -> int:
	return ops.size()
