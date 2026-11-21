## Farm visuals for one zone (spec 10.2, plan P2B.5): CropView per crop, sprinkler boxes and a
## SoilOverlay MultiMesh darkening soil watered today. Rebuilt from FarmService data.
class_name FarmView
extends Node3D

var zone_id: StringName
var crop_views: Dictionary = {}   # crop key -> CropView
var overlay: MultiMeshInstance3D
var _dirty := true


func _ready() -> void:
	overlay = MultiMeshInstance3D.new()
	overlay.name = "SoilOverlay"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.06, 0.03, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plane.material = mat
	mm.mesh = plane
	overlay.multimesh = mm
	add_child(overlay)
	EventBus.farm_changed.connect(_on_changed)
	EventBus.day_started.connect(_on_day)
	rebuild()


func _exit_tree() -> void:
	if EventBus.farm_changed.is_connected(_on_changed):
		EventBus.farm_changed.disconnect(_on_changed)
	if EventBus.day_started.is_connected(_on_day):
		EventBus.day_started.disconnect(_on_day)


func _on_changed(z: StringName) -> void:
	if z == zone_id:
		rebuild()


func _on_day(_d: int) -> void:
	rebuild()


func rebuild() -> void:
	var s := GameSession.current
	if s == null:
		return
	var farm := s.farm.model
	var prefix := String(zone_id) + "/"
	for k in crop_views.keys():
		crop_views[k].queue_free()
	crop_views.clear()
	for n in get_children():
		if n.is_in_group(&"farm_sprinkler"):
			n.queue_free()
	for k in farm.crops:
		if not String(k).begins_with(prefix):
			continue
		var c: Dictionary = farm.crops[k]
		var def: CropDef = Database.crops.get(StringName(c["crop_id"]))
		if def == null:
			continue
		var v := CropView.new()
		v.name = "Crop_" + String(k).get_file().replace(",", "_")
		add_child(v)
		v.setup(def, int(c["growth_days"]))
		v.position = Vector3(FarmModel.parse_key(k)[1])
		crop_views[k] = v
	for k in farm.sprinklers:
		if String(k).begins_with(prefix):
			var sp: Node3D = Node3D.new()
			if WorldObject.add_art(sp, ArtPaths.PROPS + "Bucket_Wooden_1.gltf", AABB(Vector3(0.25, 0, 0.25), Vector3(0.5, 0.5, 0.5))) == null:
				sp.free()
				sp = WorldObject.box_mesh(Vector3(0.35, 0.5, 0.35), Color(0.6, 0.65, 0.7), Vector3(0.5, 0.25, 0.5))
			sp.add_to_group(&"farm_sprinkler")
			add_child(sp)
			sp.position += Vector3(FarmModel.parse_key(k)[1])
	var wet: Array = []
	for k in farm.wet:
		if String(k).begins_with(prefix) and int(farm.wet[k]) == s.day():
			wet.append(FarmModel.parse_key(k)[1])
	overlay.multimesh.instance_count = wet.size()
	for i in wet.size():
		var c: Vector3i = wet[i]
		overlay.multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(c) + Vector3(0.5, 1.01, 0.5)))


func stage_of(crop_key: String) -> int:
	return crop_views[crop_key].stage if crop_views.has(crop_key) else -1
