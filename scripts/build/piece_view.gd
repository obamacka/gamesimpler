## Placeholder piece visual and collision (plan P3.1): boxes from BuildPieceDef.parts on the
## build_pieces layer, a loose-piece ToolTargetZone (P3.9) and furniture interactables (P3.12).
class_name PieceView
extends Node3D

const LAYER := 64   # build_pieces (layer 7)

var uid := ""
var def: BuildPieceDef
var state: StringName = &"LOOSE"
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
	for p in def.parts:
		var center: Vector3 = p["center"] - Vector3(0.5, 0, 0.5)
		add_child(WorldObject.box_mesh(p["size"], color, center))
		if p["solid"]:
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = p["size"]
			cs.shape = box
			cs.position = center
			body.add_child(cs)
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
