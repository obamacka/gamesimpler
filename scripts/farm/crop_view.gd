## Placeholder crop visual (spec 10.3): a box that grows with the stage; ripe crops glow.
## Final art replaces the mesh with CropDef stage meshes.
class_name CropView
extends Node3D

var crop_id: StringName
var stage := 0
var ripe := false


func setup(def: CropDef, growth_days: int) -> void:
	crop_id = def.id
	stage = def.stage_for(growth_days)
	ripe = def.is_ripe(growth_days)
	var h := 0.15 + 0.75 * float(stage) / float(def.stage_count())
	var color := def.color if ripe else def.color.lerp(Color(0.3, 0.6, 0.2), 0.6)
	var m := WorldObject.box_mesh(Vector3(0.5, h, 0.5), color, Vector3(0.5, h * 0.5, 0.5))
	if ripe:
		var mat: StandardMaterial3D = (m.mesh as BoxMesh).material
		mat.emission_enabled = true
		mat.emission = def.color
		mat.emission_energy_multiplier = 0.4
	add_child(m)
