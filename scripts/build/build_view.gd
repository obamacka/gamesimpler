## All piece views of one zone (spec 1.3 BuildGrid), rebuilt from BuildService data.
## Markers named by piece uid let beds be home beds (SleepDirector finds them by key).
class_name BuildView
extends Node3D

var zone_id: StringName
var views: Dictionary = {}   # uid -> PieceView


func _ready() -> void:
	EventBus.build_changed.connect(_on_changed)
	EventBus.furniture_toggled.connect(func(_u, _s): pass)
	rebuild()


func _exit_tree() -> void:
	if EventBus.build_changed.is_connected(_on_changed):
		EventBus.build_changed.disconnect(_on_changed)


func _on_changed(z: StringName) -> void:
	if z == zone_id:
		rebuild()


func rebuild() -> void:
	var s := GameSession.current
	if s == null:
		return
	var keep := {}
	for inst in s.build.pieces_in(zone_id):
		var uid: String = inst["uid"]
		keep[uid] = true
		var v: PieceView = views.get(uid)
		if v and v.state == inst["state"]:
			continue
		if v:
			remove_child(v)
			v.queue_free()
		v = PieceView.new()
		v.setup(inst)
		add_child(v)
		views[uid] = v
	for uid in views.keys():
		if not keep.has(uid):
			views[uid].queue_free()
			views.erase(uid)
