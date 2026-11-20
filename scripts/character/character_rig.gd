## Character visual (spec 11.5 to 11.7): the Regular-proportion skeleton of the Quaternius
## outfit pack, the head cut out of the Superhero body by skin weights, a hairstyle, and
## outfit parts per slot over a base layer, driven by the merged Universal Animation Library.
## The rig faces -Z (Godot forward) and is scaled to HEIGHT.
class_name CharacterRig
extends Node3D

const ROOT := "res://assets/third_party/quaternius/"
const HEIGHT := 1.7
const BLEND := 0.15
const MALE := &"MALE"
const FEMALE := &"FEMALE"
const HEAD_BONES: Array[String] = ["Head", "neck_01"]
const SKELETON_SRC := {MALE: "outfits/Male_Peasant_Body.gltf", FEMALE: "outfits/Female_Peasant_Body.gltf"}
const HEAD_SRC := {MALE: "characters/Superhero_Male_FullBody.gltf", FEMALE: "characters/Superhero_Female_FullBody.gltf"}
## Base layer per empty slot (spec 11.5), shown in the alternate Peasant texture.
const BASE_PARTS := {
	MALE: {&"TOP": ["Male_Peasant_Body", "Male_Peasant_Arms"], &"BOTTOM": ["Male_Peasant_Legs"], &"FEET": ["Male_Peasant_Feet"]},
	FEMALE: {&"TOP": ["Female_Peasant_Body", "Female_Peasant_Arms"], &"BOTTOM": ["Female_Peasant_Legs"], &"FEET": ["Female_Peasant_Feet"]},
}
const BASE_TEXTURE := "T_Peasant_2_BaseColor.png"
## Placeholder pieces (no parts) hang off these bones (spec 11.6): [bone, size, offset above the bone].
const PLACEHOLDER := {&"HEAD": ["Head", Vector3(0.34, 0.12, 0.34), 0.13], &"ACCESSORY": ["neck_01", Vector3(0.3, 0.1, 0.24), -0.06],
	&"TOP": ["spine_02", Vector3(0.4, 0.4, 0.26), 0.0], &"BOTTOM": ["pelvis", Vector3(0.36, 0.4, 0.24), -0.2], &"FEET": ["root", Vector3(0.36, 0.1, 0.26), 0.05]}

static var _heads := {}      # body -> {"meshes": [[ArrayMesh, Skin]], "top": float}
static var _library: AnimationLibrary

var body: StringName = FEMALE
var hair_id := ""
var armature: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var hair: MeshInstance3D
var slot_nodes := {}          # slot -> Array[Node3D] (meshes or bone attachments)
var current_clip: StringName = &""
var held_path := ""
var held: BoneAttachment3D        # right-hand attachment for the equipped tool (spec 11.10)
var _next: StringName = &""
var _hand_ref := Transform3D()    # hand_r pose in skeleton space on Idle frame 0


## Builds the body. Call once, before set_outfit.
func setup(p_body: StringName, p_hair: String) -> void:
	body = p_body if p_body in [MALE, FEMALE] else FEMALE
	hair_id = p_hair
	var src: Node = (load(ROOT + SKELETON_SRC[body]) as PackedScene).instantiate()
	armature = src.get_node("Armature")
	armature.owner = null
	src.remove_child(armature)
	src.free()
	add_child(armature)
	skeleton = armature.get_node("Skeleton3D")
	for c in skeleton.get_children():
		skeleton.remove_child(c)
		c.free()
	var head := _head(body)
	for pair in head["meshes"]:
		var mi := MeshInstance3D.new()
		mi.mesh = pair[0]
		mi.skin = pair[1]
		mi.name = "Head" if skeleton.get_child_count() == 0 else "Face%d" % skeleton.get_child_count()
		_attach(mi)
	if not hair_id.is_empty() and ResourceLoader.exists(ROOT + "hair/%s.gltf" % hair_id):
		var hs := _part_meshes("hair/%s.gltf" % hair_id)
		if not hs.is_empty():
			hair = hs[0]
			hair.name = "Hair"
	var head_y := skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin.y
	scale = Vector3.ONE * (HEIGHT / (head_y + float(head["top"])))
	rotation.y = PI
	anim = AnimationPlayer.new()
	anim.name = "Anim"
	add_child(anim)
	anim.add_animation_library(&"", library())
	anim.animation_finished.connect(_on_finished)
	set_outfit({}, [])
	play({"clip": CharacterAnimModel.IDLE})
	anim.seek(0.0, true)
	_hand_ref = skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))


## worn: slot -> {"parts": Array[String] (outfit file names), "texture": String, "tint": Color}
## or {"placeholder": Color}. Empty slots show the base layer. hidden: hide_body_regions.
func set_outfit(worn: Dictionary, hidden: Array) -> void:
	for slot in slot_nodes:
		for n in slot_nodes[slot]:
			if is_instance_valid(n):
				n.get_parent().remove_child(n)
				n.queue_free()
	slot_nodes.clear()
	for slot in OutfitDef.SLOTS:
		var w: Dictionary = worn.get(slot, {})
		var nodes: Array = []
		if w.has("parts") and not (w["parts"] as Array).is_empty():
			for p in w["parts"]:
				for mi in _part_meshes("outfits/%s.gltf" % p):
					_dye(mi, String(w.get("texture", "")), w.get("tint", Color.WHITE))
					nodes.append(mi)
		else:
			if w.has("placeholder"):
				nodes.append(_placeholder(slot, w["placeholder"]))
			if BASE_PARTS[body].has(slot):
				for p in BASE_PARTS[body][slot]:
					for mi in _part_meshes("outfits/%s.gltf" % p):
						_dye(mi, BASE_TEXTURE, Color.WHITE)
						nodes.append(mi)
		slot_nodes[slot] = nodes
	if hair:
		hair.visible = not (&"HAIR" in hidden)


## set_outfit input from worn stacks keyed by slot ({"item_id", "data": {"dye"}}, as in
## OutfitModel.slots): parts in the dye colour, or a placeholder in the dye or piece colour.
static func worn_from_slots(slots: Dictionary, p_body: StringName) -> Dictionary:
	var out := {}
	for slot in slots:
		var st = slots[slot]
		if st == null:
			continue
		var def := OutfitModel.outfit_of(StringName(st["item_id"]))
		if def == null:
			continue
		var dye: DyeDef = Database.dyes.get(StringName((st.get("data", {}) as Dictionary).get("dye", "")))
		if not def.parts_for(p_body).is_empty():
			out[def.slot] = {"parts": def.parts_for(p_body), "texture": def.texture, "tint": dye.color if dye else Color.WHITE}
		else:
			out[def.slot] = {"placeholder": dye.color if dye else def.color}
	return out


## NPC look (spec 11.6): appearance outfit item ids, each in its default dye.
static func worn_from_items(item_ids: Array, p_body: StringName) -> Dictionary:
	var slots := {}
	for it in item_ids:
		var def := OutfitModel.outfit_of(StringName(it))
		if def:
			slots[def.slot] = {"item_id": it, "data": {"dye": String(def.default_dye_id)}}
	return worn_from_slots(slots, p_body)


static func hidden_from_items(item_ids: Array) -> Array:
	var out := []
	for it in item_ids:
		var def := OutfitModel.outfit_of(StringName(it))
		if def:
			out.append_array(def.hide_body_regions)
	return out


const HELD_LENGTH := 0.6   # metres from grip to tool head
const HELD_DIRECTION := Vector3(0, 0.35, 1)   # skeleton space: forward and a little up

## Shows `path` (a tool model, spec 11.10) in the right hand, or nothing for "". Repeats are ignored.
func set_held(path: String) -> void:
	if path == held_path:
		return
	held_path = path
	if held:
		held.get_parent().remove_child(held)
		held.queue_free()
		held = null
	var m := ModelFit.instantiate(path)
	if m == null:
		return
	held = BoneAttachment3D.new()
	held.name = "Held"
	held.bone_name = "hand_r"
	skeleton.add_child(held)
	var pivot := Node3D.new()
	held.add_child(pivot)
	pivot.add_child(m)
	# Model: handle along +Y from y = 0. Fit to HELD_LENGTH tall (in metres, so undo the rig scale).
	var len := HELD_LENGTH / scale.x
	ModelFit.fit(m, AABB(Vector3(-len, -len * 0.15, -len), Vector3(len * 2.0, len, len * 2.0)), 0)
	# Point +Y along HELD_DIRECTION at the Idle hand pose, expressed in the hand bone's frame.
	var up := HELD_DIRECTION.normalized()
	var side := Vector3.RIGHT
	var want := Basis(side, up, side.cross(up).normalized()).orthonormalized()
	pivot.transform = _hand_ref.affine_inverse() * Transform3D(want, _hand_ref.origin)


## Plays {"clip", "then", "hold"} from CharacterAnimModel; repeated requests are ignored.
func play(r: Dictionary) -> void:
	var clip: StringName = r.get("clip", CharacterAnimModel.IDLE)
	if anim == null or not anim.has_animation(clip):
		return
	if clip == current_clip:
		return
	current_clip = clip
	_next = r.get("then", &"")
	anim.play(clip, BLEND)
	if r.get("hold", false):
		anim.seek(0.0, true)
		anim.pause()


func _on_finished(name: StringName) -> void:
	if name == current_clip and _next != &"" and anim.has_animation(_next):
		var n := _next
		_next = &""
		anim.play(n, BLEND)


## Meshes of every part-scene node under skeleton nodes, re-parented to this skeleton.
func _part_meshes(rel: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if not ResourceLoader.exists(ROOT + rel):
		return out
	var src: Node = (load(ROOT + rel) as PackedScene).instantiate()
	var sk := src.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	if sk:
		for c in sk.get_children():
			if c is MeshInstance3D:
				var mi := c as MeshInstance3D
				mi.skin = named_skin(mi.skin, sk)
				mi.owner = null
				sk.remove_child(mi)
				_attach(mi)
				out.append(mi)
	src.free()
	return out


func _attach(mi: MeshInstance3D) -> void:
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")


## Cloth surfaces (not the skin) take the texture override and the dye (spec 11.6).
func _dye(mi: MeshInstance3D, texture: String, tint: Color) -> void:
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
		if m == null or m.resource_name.begins_with("MI_Regular"):
			continue
		var d := m.duplicate() as BaseMaterial3D
		if not texture.is_empty() and ResourceLoader.exists(ROOT + "outfits/" + texture):
			d.albedo_texture = load(ROOT + "outfits/" + texture)
		d.albedo_color = tint.lerp(Color.WHITE, 0.3) if tint != Color.WHITE else Color.WHITE
		mi.set_surface_override_material(i, d)


func _placeholder(slot: StringName, color: Color) -> Node3D:
	var spec: Array = PLACEHOLDER[slot]
	var att := BoneAttachment3D.new()
	att.bone_name = spec[0]
	skeleton.add_child(att)
	var box := WorldObject.box_mesh(spec[1], color)
	var bone := skeleton.find_bone(spec[0])
	var rest := skeleton.get_bone_global_rest(bone)
	# Offset straight up in skeleton space, expressed in the bone's frame.
	var want := Transform3D(Basis(), rest.origin + Vector3(0, float(spec[2]), 0))
	box.transform = rest.affine_inverse() * want
	att.add_child(box)
	return att


## Skin whose binds are named, so it binds to any skeleton with the same bone names.
static func named_skin(skin: Skin, src: Skeleton3D) -> Skin:
	if skin == null:
		return null
	var out := skin.duplicate() as Skin
	for i in out.get_bind_count():
		if out.get_bind_name(i) == &"" and out.get_bind_bone(i) >= 0:
			out.set_bind_name(i, src.get_bone_name(out.get_bind_bone(i)))
	return out


## Head meshes of a body (spec 11.5): the Superhero body cut to the triangles whose vertices
## are dominated by HEAD_BONES, plus the eye and eyebrow meshes. Cached per body.
static func _head(p_body: StringName) -> Dictionary:
	if _heads.has(p_body):
		return _heads[p_body]
	var src: Node = (load(ROOT + HEAD_SRC[p_body]) as PackedScene).instantiate()
	var sk: Skeleton3D = src.get_node("Armature/Skeleton3D")
	var biggest: MeshInstance3D
	var meshes: Array = []
	for c in sk.get_children():
		if c is MeshInstance3D and (biggest == null or _vertex_count(c.mesh) > _vertex_count(biggest.mesh)):
			biggest = c
	var top := 0.0
	for c in sk.get_children():
		if not (c is MeshInstance3D):
			continue
		var skin := named_skin((c as MeshInstance3D).skin, sk)
		if c == biggest:
			var cut := cut_mesh((c as MeshInstance3D).mesh as ArrayMesh, skin, HEAD_BONES)
			meshes.push_front([cut, skin])
			top = cut.custom_aabb.end.y
		else:
			meshes.append([(c as MeshInstance3D).mesh, skin])
	var head_y := sk.get_bone_global_rest(sk.find_bone("Head")).origin.y
	src.free()
	_heads[p_body] = {"meshes": meshes, "top": top - head_y}
	return _heads[p_body]


static func _vertex_count(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		n += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n


## Keeps the triangles whose three vertices' strongest bone is in `bones` (pure mesh op).
static func cut_mesh(src: ArrayMesh, skin: Skin, bones: Array[String]) -> ArrayMesh:
	var keep := {}
	for i in skin.get_bind_count():
		if String(skin.get_bind_name(i)) in bones:
			keep[i] = true
	var out := ArrayMesh.new()
	for b in src.get_blend_shape_count():
		out.add_blend_shape(src.get_blend_shape_name(b))
	out.blend_shape_mode = src.blend_shape_mode
	var bounds := AABB()
	var have := false
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var vb: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var vw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := vb.size() / maxi(verts.size(), 1)
		var dom := PackedByteArray()
		dom.resize(verts.size())
		for v in verts.size():
			var best := -1.0
			var bone := -1
			for k in per:
				if vw[v * per + k] > best:
					best = vw[v * per + k]
					bone = vb[v * per + k]
			dom[v] = 1 if keep.has(bone) else 0
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
		var kept := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if dom[idx[t]] == 1 and dom[idx[t + 1]] == 1 and dom[idx[t + 2]] == 1:
				kept.append_array([idx[t], idx[t + 1], idx[t + 2]])
		if kept.is_empty():
			continue
		for i in kept:
			if have:
				bounds = bounds.expand(verts[i])
			else:
				bounds = AABB(verts[i], Vector3.ZERO)
				have = true
		arr[Mesh.ARRAY_INDEX] = kept
		# Keep the source format flags: custom channel formats and 8-bone weights.
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, src.surface_get_blend_shape_arrays(s), {}, src.surface_get_format(s))
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
	# The vertex buffer is shared with the full body; bound the mesh by the kept triangles.
	out.custom_aabb = bounds
	return out


## UAL1 and UAL2 clips in one library (spec 11.7), loaded once.
static func library() -> AnimationLibrary:
	if _library:
		return _library
	_library = AnimationLibrary.new()
	for f in ["animations/UAL1_Standard.glb", "animations/UAL2_Standard.glb"]:
		var src: Node = (load(ROOT + f) as PackedScene).instantiate()
		var ap: AnimationPlayer = src.get_node("AnimationPlayer")
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			for a in lib.get_animation_list():
				if not _library.has_animation(a):
					_library.add_animation(a, lib.get_animation(a))
		src.free()
	return _library
