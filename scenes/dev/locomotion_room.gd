## Graybox test room (plan P1.19), built in code so dimensions are exact and readable.
## Player spawn is at the origin facing -Z. Lanes along -Z:
##   x = 0   : 1 m step        (jump lands, auto-jump climbs)
##   x = 6   : 2 m step        (double jump lands)
##   x = 12  : 3 m step        (unreachable)
##   x = -6  : 2 m tall tunnel (duck fits, standing does not)
##   x = -14 : 5 m platform    (coyote time off its edge at z = -6, soft landing below)
class_name LocomotionRoom
extends Node3D

const LANE_STEP_1 := Vector3(0, 0, 0)
const LANE_STEP_2 := Vector3(6, 0, 0)
const LANE_STEP_3 := Vector3(12, 0, 0)
const LANE_TUNNEL := Vector3(-6, 0, 0)
const LANE_PLATFORM := Vector3(-14, 0, 0)
const STEP_NEAR_Z := -3.0          # near face of every step
const TUNNEL_CEILING := 2.0
const PLATFORM_HEIGHT := 5.0
const PLATFORM_EDGE_Z := -6.0

var _material := StandardMaterial3D.new()


func _ready() -> void:
	_material.albedo_color = Color(0.6, 0.62, 0.65)
	add_box(Vector3(0, -0.5, -10), Vector3(60, 1, 60))                       # floor, top at y = 0
	for lane in [[LANE_STEP_1, 1.0], [LANE_STEP_2, 2.0], [LANE_STEP_3, 3.0]]:
		var h: float = lane[1]
		add_box(lane[0] + Vector3(0, h * 0.5, STEP_NEAR_Z - 2.0), Vector3(3, h, 4))
	# Tunnel: interior x in [-7, -5], z in [-3, -9], ceiling underside at 2.0 m
	add_box(LANE_TUNNEL + Vector3(-1.5, 1.5, -6), Vector3(1, 3, 6))
	add_box(LANE_TUNNEL + Vector3(1.5, 1.5, -6), Vector3(1, 3, 6))
	add_box(LANE_TUNNEL + Vector3(0, TUNNEL_CEILING + 0.5, -6), Vector3(4, 1, 6))
	# Platform: top at 5 m, spans z in [3, -6]
	add_box(LANE_PLATFORM + Vector3(0, PLATFORM_HEIGHT * 0.5, -1.5), Vector3(4, PLATFORM_HEIGHT, 9))


func add_box(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _material
	mesh.mesh = bm
	body.add_child(mesh)
	add_child(body)
	return body
