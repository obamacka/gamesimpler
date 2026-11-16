## Build ghost (spec 2.7, plan P3.8): translucent box with outline color by palette, a status
## label (check / X + reason / magnet) and the fastener reticle. Placeholder visuals.
class_name GhostView
extends Node3D

const PALETTES := {
	&"DEFAULT": [Color(0.2, 0.9, 0.3, 0.35), Color(0.95, 0.2, 0.2, 0.35)],
	&"BLUE_ORANGE": [Color(0.2, 0.5, 1.0, 0.35), Color(1.0, 0.55, 0.1, 0.35)],
	&"HIGH_CONTRAST": [Color(1, 1, 1, 0.6), Color(0.1, 0.1, 0.1, 0.6)],
}
const REASON_TEXT := {
	&"occupied": "Something is here", &"no_support": "Needs support below", &"outside_plot": "Not your plot",
	&"overlaps_player": "You are in the way", &"missing_item": "None left", &"protected": "Protected",
	&"inside_player": "You are in the way", &"inside_pet": "Pet is in the way", &"outside_reach": "Too far",
}

var box: MeshInstance3D
var label: Label3D
var reticle: MeshInstance3D
var state: StringName = &"hidden"   # hidden, valid, invalid, snapped
var reason: StringName = &""


func _ready() -> void:
	top_level = true
	box = MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material_override = mat
	add_child(box)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	add_child(label)
	reticle = WorldObject.box_mesh(Vector3(0.08, 0.08, 0.08), Color(1, 0.9, 0.2))
	reticle.top_level = true
	add_child(reticle)
	hide_all()


func hide_all() -> void:
	box.visible = false
	label.visible = false
	reticle.visible = false
	state = &"hidden"


## preview: {"cells": Array[Vector3i], "valid": bool, "reason", "snapped": bool}
func show_preview(preview: Dictionary, palette: StringName) -> void:
	var cells: Array = preview.get("cells", [])
	if cells.is_empty():
		hide_all()
		return
	var lo: Vector3i = cells[0]
	var hi: Vector3i = cells[0]
	for c in cells:
		lo = Vector3i(mini(lo.x, c.x), mini(lo.y, c.y), mini(lo.z, c.z))
		hi = Vector3i(maxi(hi.x, c.x), maxi(hi.y, c.y), maxi(hi.z, c.z))
	var size := Vector3(hi - lo) + Vector3.ONE
	(box.mesh as BoxMesh).size = size * 0.98
	global_position = Vector3(lo) + size * 0.5
	var colors: Array = PALETTES.get(palette, PALETTES[&"DEFAULT"])
	var valid: bool = preview.get("valid", false)
	(box.material_override as StandardMaterial3D).albedo_color = colors[0] if valid else colors[1]
	box.visible = true
	label.visible = true
	label.position = Vector3(0, size.y * 0.5 + 0.4, 0)
	reason = preview.get("reason", &"")
	if not valid:
		state = &"invalid"
		label.text = "X " + REASON_TEXT.get(reason, String(reason))
	elif preview.get("snapped", false):
		state = &"snapped"
		label.text = "magnet"
	else:
		state = &"valid"
		label.text = "ok"


func show_reticle(pos: Variant) -> void:
	reticle.visible = pos != null
	if pos != null:
		reticle.global_position = pos
