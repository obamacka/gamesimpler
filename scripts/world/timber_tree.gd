## Timber tree or fallen log (spec D8): chopped with the AXE via the Mine state.
class_name TimberTree
extends WorldObject

@export var key := ""
@export var def_id: StringName = &"timber_oak"

var _visual: Node3D
var _body: StaticBody3D


func _ready() -> void:
	if key == "":
		key = "%s/%s" % [SceneRouter.current_zone_id, name]
	_visual = Node3D.new()
	add_child(_visual)
	var log := def_id == &"log_fallen"
	if log:
		_visual.add_child(box_mesh(Vector3(2.0, 0.5, 0.5), Color(0.4, 0.27, 0.15), Vector3(0, 0.25, 0)))
		_body = add_static_box(self, Vector3(2.0, 0.5, 0.5), Vector3(0, 0.25, 0))
	else:
		_visual.add_child(box_mesh(Vector3(0.5, 3.0, 0.5), Color(0.4, 0.27, 0.15), Vector3(0, 1.5, 0)))
		_visual.add_child(box_mesh(Vector3(2.0, 2.0, 2.0), Color(0.2, 0.45, 0.2), Vector3(0, 3.5, 0)))
		_body = add_static_box(self, Vector3(0.5, 3.0, 0.5), Vector3(0, 1.5, 0))
	make_tool_zone(key, ToolTypes.AXE, &"timber", 20, 2.5)
	var s := session()
	if s:
		s.world_state.register_timber(key, def_id)
		s.terrain.rules.protect_support(base_cell(), key)


func _process(_delta: float) -> void:
	var standing := tool_zone_active()
	_visual.visible = standing
	_body.process_mode = Node.PROCESS_MODE_INHERIT if standing else Node.PROCESS_MODE_DISABLED


func tool_zone_active() -> bool:
	var s := session()
	return s != null and not s.world_state.is_chopped(key)
