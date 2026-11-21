## Scenery (spec 12.3): a model fitted into `size` (standing on the node's origin), turned by
## `yaw_deg`, with an optional box collider of the fitted size. The voxel under it is
## protected so digging cannot leave it floating. Seating decor (`seat_count` > 0) can be sat
## on like built seating (spec 12.6).
class_name DecorProp
extends WorldObject

@export_file("*.gltf", "*.glb", "*.fbx", "*.tscn") var model := ""
@export var size := Vector3(1, 1, 1)
@export var yaw_deg := 0
@export var solid := true
## Furniture: show at the KayKit world scale (spec 11.4) instead of fitting into `size`.
@export var use_world_scale := false
## Non-zero: show the model at this fixed scale with its own pivot (spec 12.8: houses, metric
## props) instead of fitting it into `size`.
@export var model_scale := 0.0
## Non-zero: the collider box (standing on the origin) instead of the model's box (trees: trunk).
@export var collider := Vector3.ZERO
## Seats side by side across the model's width (chairs 1, sofas 2); 0 = not a seat.
@export var seat_count := 0

var seats: Array[Vector3] = []   # world positions
var exits: Array[Vector3] = []

var art: Node3D


func _ready() -> void:
	if use_world_scale:
		var m := ModelFit.instantiate(model)
		if m:
			art = Node3D.new()
			art.name = "Art"
			add_child(art)
			art.add_child(m)
			ModelFit.place(m, AABB(), yaw_deg)
	elif model_scale > 0.0:
		art = add_art_at(self, model, model_scale, yaw_deg)
	else:
		art = add_art(self, model, AABB(Vector3(-size.x * 0.5, 0, -size.z * 0.5), size), yaw_deg)
	if art and solid:
		if collider != Vector3.ZERO:
			add_static_box(self, collider, Vector3(0, collider.y * 0.5, 0))
		else:
			var b := art_collision(art)
			add_static_box(self, b.size, b.get_center())
	var s := session()
	if s and s.terrain and s.terrain.rules:
		s.terrain.rules.protect_support(base_cell(), "decor:%s/%s" % [SceneRouter.current_zone_id, name])
	if art and seat_count > 0:
		_make_seats()


## Seats over the front three quarters (in front of the backrest), at the model's seat height
## (spec 12.8: highest point over the front 40%); exits 0.6 m ahead.
func _make_seats() -> void:
	var b := art_bounds(art)
	var m: Node3D = art.get_child(0)
	var y := ModelFit.seat_height(m, art.transform * m.transform)
	var z := b.position.z + b.size.z * 0.625
	for i in seat_count:
		var x := b.position.x + b.size.x * (i + 0.5) / seat_count
		seats.append(global_transform * Vector3(x, y, z))
		exits.append(global_transform * Vector3(x, 0, b.end.z + 0.6))
	var it := Interactable.new()
	it.key = "decor:%s" % get_path()
	it.kind = &"SIT"
	it.radius = 1.2
	it.position = Vector3(0, 0.8, 0)
	add_child(it)


func seat_regen() -> float:
	return Database.stamina.sit_regen_per_sec


## Index of the nearest seat (single player: any seat), or -1.
func free_seat(player: Node) -> int:
	var best := -1
	var best_d := INF
	for i in seats.size():
		var d := (player as Node3D).global_position.distance_to(seats[i]) if player is Node3D else float(i)
		if d < best_d:
			best = i
			best_d = d
	return best


func interaction_spec(player: Node, _forage: bool, alt: bool) -> InteractionSpec:
	if alt or seats.is_empty() or free_seat(player) < 0:
		return null
	return InteractionSpec.new(&"SIT", 0.0, 0, &"sit")


func resolve_interaction(_spec: InteractionSpec, _player: Node) -> void:
	pass
