## Piece visual and collision (plan P3.1): boxes from BuildPieceDef.parts on the build_pieces
## layer, a loose-piece ToolTargetZone (P3.9) and furniture interactables (P3.12). Pieces with
## a model (spec 11.3) show it fitted to the parts box instead of the placeholder boxes; the
## parts still give the collision.
class_name PieceView
extends Node3D

const LAYER := 64   # build_pieces (layer 7)
const SHADER := preload("res://resources/shaders/piece.gdshader")
const REGION_INDEX := {&"PRIMARY": 1, &"SECONDARY": 2, &"TRIM": 3}

var uid := ""
var def: BuildPieceDef
var state: StringName = &"LOOSE"
var meshes: Array[MeshInstance3D] = []   # every visible mesh that takes paint
var model: Node3D                         # fitted art model, or null for placeholder boxes
var decals: Array[Decal] = []
var seats: Array[Vector3] = []     # world seat positions
var exits: Array[Vector3] = []


func setup(inst: Dictionary) -> void:
	uid = inst["uid"]
	def = Database.pieces[StringName(inst["piece_id"])]
	state = inst["state"]
	name = uid
	var r: int = inst["rot"]
	position = Vector3(inst["cell"]) + Vector3(0.5, 0, 0.5)
	rotation.y = r * PI / 2.0
	var color := def.color if state == &"FASTENED" else def.color.lerp(Color(1, 1, 1), 0.45)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER
	body.collision_mask = 0
	body.set_meta(&"uid", uid)
	add_child(body)
	if def.has_model():
		_build_model()
	for p in def.parts:
		var center: Vector3 = p["center"] - Vector3(0.5, 0, 0.5)
		if p["solid"]:
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = p["size"]
			cs.shape = box
			cs.position = center
			body.add_child(cs)
		if model:
			continue
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p["size"]
		mi.mesh = bm
		mi.position = center
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter(&"base_color", color)
		mat.set_shader_parameter(&"region", REGION_INDEX.get(p.get("region", &""), 0))
		mi.material_override = mat
		add_child(mi)
		meshes.append(mi)
	apply_decor(inst)
	if state == &"LOOSE" and def.needs_fastening():
		var z := ToolTargetZone.new()
		z.key = "piece:" + uid
		z.tool = ToolTypes.HAMMER if def.fastener == BuildPieceDef.NAILS else ToolTypes.SCREWDRIVER
		z.target_kind = &"loose_piece"
		z.tool_priority = 40
		z.enter_radius = 3.0
		add_child(z)
	var sit := def.interaction(&"SIT")
	for s in sit.get("seats", []):
		seats.append(BuildGrid.world_point(inst["cell"], r, s))
	for e in sit.get("exits", []):
		exits.append(BuildGrid.world_point(inst["cell"], r, e))
	if not def.interactions.is_empty():
		var i := Interactable.new()
		i.key = uid
		i.kind = def.interactions[0]["kind"]
		i.radius = 1.2
		i.position = Vector3(0, 0.8, 0)
		add_child(i)


static var _materials := {}   # [texture, region, lighten] -> ShaderMaterial, shared by all views


func _build_model() -> void:
	model = ModelFit.instantiate(def.model_scene)
	if model == null:
		return
	model.name = "Model"
	add_child(model)
	var box := def.fit_box()
	box.position -= Vector3(0.5, 0, 0.5)
	ModelFit.fit(model, box, def.model_yaw_deg)
	var region := REGION_INDEX[&"PRIMARY"] if def.region_param(&"PRIMARY") != &"" else 0
	var lighten := 0.0 if state == &"FASTENED" else 0.45
	for mi in ModelFit.mesh_instances(model):
		mi.material_override = model_material(mi.get_active_material(0), region, lighten)
		meshes.append(mi)


## Piece shader material for an imported surface: samples its albedo texture (spec 11.3).
static func model_material(src: Material, region: int, lighten: float) -> ShaderMaterial:
	var tex: Texture2D = (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null
	var key := [tex.get_rid() if tex else RID(), region, lighten, (src as BaseMaterial3D).albedo_color if src is BaseMaterial3D else Color.WHITE]
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"use_texture", tex != null)
	mat.set_shader_parameter(&"albedo_tex", tex)
	mat.set_shader_parameter(&"base_color", key[3])
	mat.set_shader_parameter(&"region", region)
	mat.set_shader_parameter(&"lighten", lighten)
	_materials[key] = mat
	return mat


## Paint (spec 7.2): one instance shader parameter per region on every part; no material
## duplication. Stamps: one Decal per stamp in local space.
func apply_decor(inst: Dictionary) -> void:
	for mi in meshes:
		for r in def.paint_regions:
			mi.set_instance_shader_parameter(r["shader_param"], PaintModel.color_of(inst, r["region_id"]))
	for d in decals:
		d.queue_free()
	decals.clear()
	for st in inst.get("stamps", []):
		var dc := Decal.new()
		var size: float = StampModel.SIZES.get(st["size"], 0.5)
		dc.size = Vector3(size, 0.3, size)
		var tex := GradientTexture2D.new()
		tex.width = 64
		tex.height = 64
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		var g := Gradient.new()
		var sticker: StickerDef = Database.stickers.get(StringName(st["sticker_id"]))
		var c := sticker.color if sticker else Color.WHITE
		g.set_color(0, c)
		g.set_color(1, Color(c.r, c.g, c.b, 0.0))
		tex.gradient = g
		dc.texture_albedo = tex
		var p: Array = st["pos"]
		var n: Array = st["normal"]
		var normal := Vector3(n[0], n[1], n[2]).normalized()
		dc.position = Vector3(p[0], p[1], p[2])
		# A Decal projects along its local -Y: +Y follows the surface normal, rotation turns it.
		var up := normal if normal.length() > 0.5 else Vector3.UP
		var x := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		dc.basis = Basis(x, up, x.cross(up)).orthonormalized().rotated(up, deg_to_rad(float(st["rot_deg"])))
		dc.set_meta(&"sticker", st["sticker_id"])
		add_child(dc)
		decals.append(dc)


## Loose-piece zones are active only in Build mode with the Place tool (spec 2.6).
func tool_zone_active() -> bool:
	var p := SceneRouter.player
	return is_instance_valid(p) and p.has_method("build_place_active") and p.build_place_active()


func interaction_spec(player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	var s := GameSession.current
	if s == null or not s.build.pieces.has(uid):
		return null
	for i in def.interactions:
		match i["kind"]:
			&"SIT":
				if not alt and free_seat(player) >= 0:
					return InteractionSpec.new(&"SIT", 0.0, 0, &"sit")
			&"TOGGLE":
				if not alt:
					return InteractionSpec.new(&"TOGGLE", 0.3)
			&"STORAGE", &"FEED_BOWL":
				if not alt:
					var st := InteractionSpec.new(&"STORAGE", 0.2)
					st.opens_menu = &"storage"
					st.menu_args = {"uid": uid}
					return st
			&"SLEEP":
				var spec := InteractionSpec.new(&"SET_HOME" if alt else &"BED", 0.0)
				spec.opens_menu = &"confirm"
				spec.menu_args = {"text": "Make this bed your home?" if alt else "Sleep until morning?", "default_yes": not alt}
				return spec
	return null


func resolve_interaction(spec: InteractionSpec, player: Node) -> void:
	var s := GameSession.current
	match spec.kind:
		&"TOGGLE":
			s.build.toggle_furniture(uid)
		&"BED":
			if spec.menu_result == &"yes":
				player.pending_sleep_reason = &"bed"
				spec.handoff_state = &"sleep"
		&"SET_HOME":
			if spec.menu_result == &"yes":
				s.housing.set_home_bed(SceneRouter.current_zone_id, StringName(uid))


## Index of the nearest seat nobody else uses (single player: any seat), or -1.
func free_seat(player: Node) -> int:
	var best := -1
	var best_d := INF
	for i in seats.size():
		var d := (player as Node3D).global_position.distance_to(seats[i]) if player is Node3D else float(i)
		if d < best_d:
			best = i
			best_d = d
	return best
