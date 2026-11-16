## Command result (spec 1.5): commands return this instead of emitting on failure.
class_name Result
extends RefCounted

var ok: bool
var error: StringName
var data: Variant


func _init(is_ok: bool = true, err: StringName = &"", payload: Variant = null) -> void:
	ok = is_ok
	error = err
	data = payload


static func success(payload: Variant = null) -> Result:
	return Result.new(true, &"", payload)


static func failure(err: StringName, payload: Variant = null) -> Result:
	return Result.new(false, err, payload)
