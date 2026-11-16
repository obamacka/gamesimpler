## Records signal emissions from one source in order, with their arguments and
## the physics frame they were emitted on. Used for ordered-signal assertions
## (spec 8.2 item 5). Call stop() in after_test to disconnect.
class_name SignalRecorder
extends RefCounted

const MAX_ARGS := 6

var records: Array[Dictionary] = []

var _source: Object
var _connections: Array[Dictionary] = []


func _init(source: Object, signal_names: Array[StringName]) -> void:
	_source = source
	for signal_name in signal_names:
		assert(source.has_signal(signal_name), "SignalRecorder: unknown signal %s" % signal_name)
		var arg_count := _arg_count(source, signal_name)
		assert(arg_count <= MAX_ARGS, "SignalRecorder: %s has more than %d args" % [signal_name, MAX_ARGS])
		var callable := _make_callable(signal_name, arg_count)
		source.connect(signal_name, callable)
		_connections.append({"name": signal_name, "callable": callable})


## Disconnects from every recorded signal. Safe to call more than once.
func stop() -> void:
	if not is_instance_valid(_source):
		_connections.clear()
		return
	for c in _connections:
		if _source.is_connected(c["name"], c["callable"]):
			_source.disconnect(c["name"], c["callable"])
	_connections.clear()


## Signal names in emission order.
func names() -> Array[StringName]:
	var result: Array[StringName] = []
	for r in records:
		result.append(r["name"])
	return result


## Number of times `signal_name` was recorded.
func count(signal_name: StringName) -> int:
	var n := 0
	for r in records:
		if r["name"] == signal_name:
			n += 1
	return n


func clear() -> void:
	records.clear()


func _record(signal_name: StringName, args: Array) -> void:
	records.append({
		"name": signal_name,
		"args": args,
		"physics_frame": Engine.get_physics_frames(),
	})


func _arg_count(source: Object, signal_name: StringName) -> int:
	for info in source.get_signal_list():
		if info["name"] == signal_name:
			return (info["args"] as Array).size()
	return 0


# One lambda per arity, because a connected callable must match the signal's argument count.
func _make_callable(n: StringName, arg_count: int) -> Callable:
	match arg_count:
		0:
			return func() -> void: _record(n, [])
		1:
			return func(a) -> void: _record(n, [a])
		2:
			return func(a, b) -> void: _record(n, [a, b])
		3:
			return func(a, b, c) -> void: _record(n, [a, b, c])
		4:
			return func(a, b, c, d) -> void: _record(n, [a, b, c, d])
		5:
			return func(a, b, c, d, e) -> void: _record(n, [a, b, c, d, e])
		_:
			return func(a, b, c, d, e, f) -> void: _record(n, [a, b, c, d, e, f])
