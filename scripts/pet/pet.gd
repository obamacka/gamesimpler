## Pet companion body (spec 7.1, 4.6). Layer pet, mask world | build_pieces: the player and
## the pet never block each other. Accessories hang on BoneAttachment3D nodes named by slot.
## Behavior comes from PetBrainModel; movement follows the PetPathProvider's points.
class_name Pet
extends CharacterBody3D

const LAYER := 8
const REST_RING := 0.8   # the pet settles inside follow_distance so Idle (dist < follow_distance) can trigger

var session: GameSession
var state: Dictionary
var species: PetSpeciesDef
var brain := PetBrainModel.new()
var provider: PetPathProvider = PetPathProvider.new()
var skeleton: Skeleton3D
var attachments: Dictionary = {}   # slot -> BoneAttachment3D
var facts: Dictionary = {}          # one-shot facts set by PetService (emote, pat, feed, call, zone_changed)
var path: Array[Vector3] = []
var _repath_t := 0.0
var _wander_t := 0.0
var _wander_target := Vector3.ZERO
var bowl_target: Variant = null
var model: Node3D                 # species art model (spec 11.8), or null for the placeholder box
var anim: AnimationPlayer
var _bone_space_scale := 1.0


static func create(s: GameSession, pet_state: Dictionary) -> Pet:
	var p := Pet.new()
	p.session = s
	p.state = pet_state
	p.species = Database.pet_species[StringName(pet_state["species_id"])]
	p.name = "Pet"
	p._build()
	return p


func _build() -> void:
	collision_layer = LAYER
	collision_mask = 1 | 64
	brain.configure(species, Database.pet_config)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = species.size
	shape.shape = box
	shape.position = Vector3(0, species.size.y * 0.5, 0)
	add_child(shape)
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var color: Color = species.variants[clampi(int(state["color_variant"]), 0, species.variants.size() - 1)] if not species.variants.is_empty() else Color.WHITE
	model = ModelFit.instantiate(species.model)
	if model:
		_build_model(visual, color)
	else:
		_build_placeholder(visual, color)
	for slot in PetAccessoryDef.SLOTS:
		var att := BoneAttachment3D.new()
		att.name = String(slot)
		att.bone_name = String(species.accessory_bones.get(String(slot), String(slot).to_lower()))
		skeleton.add_child(att)
		attachments[slot] = att
	var i := Interactable.new()
	i.key = "pet"
	i.kind = &"PET"
	i.radius = 1.0
	i.position = Vector3(0, 0.5, 0)
	add_child(i)
	refresh_accessories()


## Spec 11.8: the species model fitted to its size box, coloured by material name.
func _build_model(visual: Node3D, coat: Color) -> void:
	model.name = "Model"
	visual.add_child(model)
	ModelFit.fit(model, AABB(Vector3(-species.size.x * 0.5, 0, -species.size.z * 0.5), species.size), species.model_yaw_deg)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	var k := model.transform.basis.get_scale().x * (skeleton.get_parent() as Node3D).transform.basis.get_scale().x
	_bone_space_scale = k if k > 0.0 else 1.0
	for mi in ModelFit.mesh_instances(model):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m == null:
				continue
			var c: Variant = coat if m.resource_name in species.coat_materials else species.material_colors.get(m.resource_name)
			if c != null:
				var d := m.duplicate() as BaseMaterial3D
				d.albedo_color = c
				mi.set_surface_override_material(i, d)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0] if not model.find_children("*", "AnimationPlayer", true, false).is_empty() else null
	if anim:
		for a in [species.anim_idle, species.anim_walk]:
			if anim.has_animation(a):
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_play(species.anim_idle, 1.0)


func _build_placeholder(visual: Node3D, color: Color) -> void:
	var rig := Node3D.new()
	rig.name = "Rig"
	visual.add_child(rig)
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	rig.add_child(skeleton)
	var h := species.size.y
	var bones := {"body": Vector3(0, h * 0.6, 0), "neck": Vector3(0, h * 0.85, -species.size.z * 0.35), "head": Vector3(0, h * 1.05, -species.size.z * 0.45)}
	for b in ["body", "neck", "head"]:
		var idx := skeleton.add_bone(b)
		skeleton.set_bone_rest(idx, Transform3D(Basis(), bones[b]))
		skeleton.set_bone_pose_position(idx, bones[b])
	skeleton.add_child(WorldObject.box_mesh(species.size, color, Vector3(0, h * 0.5, 0)))


func _play(clip: StringName, speed: float) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if anim.current_animation != clip:
		anim.play(clip, 0.2)
	anim.speed_scale = speed


## Clip and facing from the velocity (spec 11.8).
func _update_visual(delta: float) -> void:
	var v := Vector2(velocity.x, velocity.z)
	if v.length() > 0.3:
		var visual: Node3D = get_node("Visual")
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-v.x, -v.y), clampf(10.0 * delta, 0.0, 1.0))
		_play(species.anim_walk, clampf(v.length() / maxf(species.walk_speed, 0.1), 0.6, 2.2))
	else:
		_play(species.anim_idle, 1.0)


func refresh_accessories() -> void:
	for slot in attachments:
		var att: BoneAttachment3D = attachments[slot]
		for c in att.get_children():
			att.remove_child(c)
			c.queue_free()
		var st = state["accessories"].get(String(slot))
		if st == null:
			continue
		var m := WorldObject.box_mesh(Vector3(0.3, 0.12, 0.3) if slot == &"HEAD" else Vector3(0.36, 0.1, 0.36), PetAccessoryModel.color_of(st))
		m.name = "Accessory"
		m.scale = Vector3.ONE / _bone_space_scale   # model skeletons are scaled; keep the box size in metres
		att.add_child(m)


func accessory_mesh(slot: StringName) -> MeshInstance3D:
	var att: BoneAttachment3D = attachments.get(slot)
	return att.get_node_or_null("Accessory") if att else null


func _player() -> Node3D:
	return SceneRouter.player


func teleport_next_to_player() -> void:
	var p := _player()
	if not is_instance_valid(p):
		return
	var back := p.global_transform.basis.z
	back.y = 0.0
	var spot := p.global_position + (back.normalized() if back.length() > 0.01 else Vector3.BACK) * species.follow_distance * REST_RING
	global_position = Vector3(spot.x, p.global_position.y, spot.z)
	velocity = Vector3.ZERO
	path.clear()


func _physics_process(delta: float) -> void:
	var p := _player()
	if not is_instance_valid(p):
		return
	var dist := global_position.distance_to(p.global_position)
	var pv := Vector2(p.velocity.x, p.velocity.z) if p is CharacterBody3D else Vector2.ZERO
	_repath_t -= delta
	var target := _target_for(p)
	if _repath_t <= 0.0 and brain.state in [PetBrainModel.FOLLOW, PetBrainModel.CALL, PetBrainModel.GO_TO_BOWL, PetBrainModel.WANDER]:
		_repath_t = 0.2   # 5 Hz (spec 7.1)
		path = provider.find_path(global_position, target)
	var f := {"dist": dist, "player_moving": pv.length() > 0.2, "player_resting": p.has_method("is_resting") and p.is_resting(),
		"has_path": not path.is_empty() or dist < 1.0, "fed_today": int(state["fed_day"]) == session.day(),
		"bowl_food": bowl_target != null, "bed_dist": session.pets.nearest_bed_distance(global_position),
		"reached": global_position.distance_to(target) < 0.9}
	f.merge(facts, true)
	facts.clear()
	var before := brain.state
	var st := brain.update(delta, f)
	if st != before:
		EventBus.pet_state_changed.emit(before, st)
	match st:
		PetBrainModel.TELEPORT:
			teleport_next_to_player()
		PetBrainModel.FOLLOW, PetBrainModel.CALL, PetBrainModel.GO_TO_BOWL, PetBrainModel.WANDER:
			_walk(delta, dist)
		_:
			velocity.x = 0.0
			velocity.z = 0.0
	if st == PetBrainModel.EAT and before == PetBrainModel.GO_TO_BOWL:
		session.pets.eat_from_bowl()
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	_update_visual(delta)
	session.terrain.rules.pet_cells = [IVoxelWorld.cell_of(global_position + Vector3(0, 0.1, 0))]


func _target_for(p: Node3D) -> Vector3:
	match brain.state:
		PetBrainModel.CALL:
			return p.global_position
		PetBrainModel.GO_TO_BOWL:
			return bowl_target if bowl_target != null else global_position
		PetBrainModel.WANDER:
			_wander_t -= get_physics_process_delta_time()
			if _wander_t <= 0.0:
				_wander_t = 3.0
				var a := session.rng.randi_range("pet", 0, 359)
				_wander_target = global_position + Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a))) * species.wander_radius * 0.5
			return _wander_target
	var back := p.global_transform.basis.z
	back.y = 0.0
	return p.global_position + (back.normalized() if back.length() > 0.01 else Vector3.BACK) * species.follow_distance * REST_RING


func _walk(_delta: float, dist: float) -> void:
	while not path.is_empty() and Vector2(path[0].x - global_position.x, path[0].z - global_position.z).length() < 0.3:
		path.remove_at(0)
	if path.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var speed := species.walk_speed if dist < 6.0 else species.run_speed
	var to := (path[0] - global_position) * Vector3(1, 0, 1)
	var v := to.normalized() * speed
	velocity.x = v.x
	velocity.z = v.z


## Nudge (spec 7.1): a placed piece covering the pet moves it to the nearest free cell.
func nudge_out_of(cells: Array) -> void:
	var c := IVoxelWorld.cell_of(global_position + Vector3(0, 0.1, 0))
	if not (c in cells):
		return
	var w := session.terrain.world
	for r in range(1, 4):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var n := c + Vector3i(dx, 0, dz)
				if not (n in cells) and w.get_voxel(n) == IVoxelWorld.AIR and w.get_voxel(n + Vector3i.UP) == IVoxelWorld.AIR \
						and not session.build.occ(SceneRouter.current_zone_id).has(BuildGrid.cell_key("b", n)):
					global_position = Vector3(n) + Vector3(0.5, 0, 0.5)
					return


func interaction_spec(player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	if not alt:
		return InteractionSpec.new(&"PET_PAT", 0.6)
	if session.pets.feedable_item() != &"" and int(state["fed_day"]) != session.day():
		return InteractionSpec.new(&"PET_FEED", 0.8)
	var d := InteractionSpec.new(&"PET_DRESS", 0.0)
	d.opens_menu = &"pet_wardrobe"
	return d


func resolve_interaction(spec: InteractionSpec, _player: Node) -> void:
	match spec.kind:
		&"PET_PAT":
			session.pets.pat()
		&"PET_FEED":
			session.pets.try_feed(session.pets.feedable_item())
