## NPC body (spec 4.5 Talk, 9.4): walks to its schedule marker inside the protected town,
## stops and faces the player while talking, reacts to emotes. X talks, Y gives a gift.
## Navigation: NavigationAgent3D when the zone has a navmesh; otherwise straight steering,
## which is safe because schedule markers sit in flat protected areas.
class_name Npc
extends CharacterBody3D

const SPEED := 1.6

@export var npc_id: StringName

var def: NpcDef
var agent: NavigationAgent3D
var talking := false
var last_reaction: StringName = &""
var _react_t := 0.0
var _talk_with: Node3D
var character: CharacterRig


func _ready() -> void:
	def = Database.npcs.get(npc_id)
	collision_layer = 4
	collision_mask = 1 | 64
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7   # same size as the player (spec 1.4, 11.4)
	shape.shape = cap
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)
	character = CharacterRig.new()
	character.name = "Character"
	add_child(character)
	var ap: Dictionary = def.appearance if def else {}
	character.setup(ap.get("body", CharacterRig.FEMALE), ap.get("hair", ""))
	character.rotation.y = 0.0   # NPC front is +Z (look_at with use_model_front)
	var outfit: Array = ap.get("outfit", [])
	character.set_outfit(CharacterRig.worn_from_items(outfit, character.body), CharacterRig.hidden_from_items(outfit))
	agent = NavigationAgent3D.new()
	add_child(agent)
	var i := Interactable.new()
	i.key = String(npc_id)
	i.kind = &"NPC"
	i.radius = 1.2
	i.position = Vector3(0, 1.0, 0)
	add_child(i)
	add_to_group(&"npcs")
	var m := _marker()
	if m:
		global_position = m.global_position


func _marker() -> Node3D:
	if def == null:
		return null
	return SceneRouter.find_marker(def.marker_at(GameClock.model.minute))


func _physics_process(delta: float) -> void:
	_react_t = maxf(0.0, _react_t - delta)
	if _react_t == 0.0:
		last_reaction = &""
	if talking:
		velocity = Vector3.ZERO
		if is_instance_valid(_talk_with):
			look_at(Vector3(_talk_with.global_position.x, global_position.y, _talk_with.global_position.z), Vector3.UP, true)
		character.play(CharacterAnimModel.for_npc(false, true, last_reaction))
		return
	var m := _marker()
	var target := m.global_position if m else global_position
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.2:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var next := target
		if NavigationServer3D.map_get_regions(get_world_3d().navigation_map).size() > 0:
			agent.target_position = target
			next = agent.get_next_path_position()
		var dir := (next - global_position) * Vector3(1, 0, 1)
		var v := dir.normalized() * SPEED
		velocity.x = v.x
		velocity.z = v.z
		if dir.length() > 0.05:
			look_at(global_position + dir, Vector3.UP, true)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	character.play(CharacterAnimModel.for_npc(Vector2(velocity.x, velocity.z).length() > 0.2, false, last_reaction))


func begin_talk(with: Node3D) -> void:
	talking = true
	_talk_with = with


func end_talk() -> void:
	talking = false
	_talk_with = null


func react(reaction: StringName) -> void:
	last_reaction = reaction
	_react_t = 2.0


func interaction_spec(_player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	if alt and def and def.is_curator:
		var dn := InteractionSpec.new(&"DONATE", 0.0)   # spec 5.8: curator Y opens donation
		dn.opens_menu = &"donation"
		return dn
	if alt:
		var g := InteractionSpec.new(&"GIFT", 0.0)
		g.opens_menu = &"gift_picker"
		g.menu_args = {"npc_id": npc_id}
		return g
	return InteractionSpec.new(&"TALK", 0.0, 0, &"talk")


func resolve_interaction(_spec: InteractionSpec, player: Node) -> void:
	player.pending_talk = self
