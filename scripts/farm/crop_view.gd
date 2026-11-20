## Crop visual (spec 10.3, 11.9). Crops with stage models show the model for the growth stage
## at one scale per crop (the ripe model fitted to 0.9 x height x 0.9) and glow softly when
## ripe. Crops without models show a box that grows with the stage; ripe ones glow and show
## their produce prop when the produce item has a world model (spec 11.3).
class_name CropView
extends Node3D

static var _scales := {}   # crop id -> uniform model scale

var crop_id: StringName
var stage := 0
var ripe := false
var model: Node3D


func setup(def: CropDef, growth_days: int) -> void:
	crop_id = def.id
	stage = def.stage_for(growth_days)
	ripe = def.is_ripe(growth_days)
	if def.has_models():
		_setup_model(def)
		return
	var h := 0.15 + 0.75 * float(stage) / float(def.stage_count())
	var color := def.color if ripe else def.color.lerp(Color(0.3, 0.6, 0.2), 0.6)
	var m := WorldObject.box_mesh(Vector3(0.5, h, 0.5), color, Vector3(0.5, h * 0.5, 0.5))
	if ripe:
		var mat: StandardMaterial3D = (m.mesh as BoxMesh).material
		mat.emission_enabled = true
		mat.emission = def.color
		mat.emission_energy_multiplier = 0.4
	add_child(m)
	if ripe:
		var produce := def.harvest_item_id
		if Database.items.has(produce) and not Database.items[produce].world_model.is_empty():
			var v := ItemVisual.make(produce, 0.45, def.color)
			v.name = "Produce"
			v.position = Vector3(0.5, h, 0.5)
			add_child(v)


static func box_for(def: CropDef) -> AABB:
	var h: float = def.models.get("height", 0.8)
	return AABB(Vector3(0.05, 0, 0.05), Vector3(0.9, h, 0.9))


## One scale per crop: what fits the ripe model into box_for(def).
static func scale_for(def: CropDef) -> float:
	if not _scales.has(def.id):
		var ripe_model := ModelFit.instantiate(def.models["ripe"])
		var holder := Node3D.new()
		holder.add_child(ripe_model)
		_scales[def.id] = ModelFit.fit(ripe_model, box_for(def), 0)
		holder.free()
	return _scales[def.id]


func _setup_model(def: CropDef) -> void:
	model = ModelFit.instantiate(def.model_for(stage, ripe))
	if model == null:
		return
	model.name = "Model"
	add_child(model)
	ModelFit.place(model, box_for(def), 0, scale_for(def))
	if ripe:
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.albedo_color = Color(def.color.r, def.color.g, def.color.b, 0.18)
		for mi in ModelFit.mesh_instances(model):
			mi.material_overlay = glow
