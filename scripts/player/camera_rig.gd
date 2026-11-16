## Third-person camera (spec 1.4, P1.17). Reads look input only from InputFrame.
## Node layout: CameraRig (yaw) -> Pitch -> SpringArm3D -> Camera3D.
class_name CameraRig
extends Node3D

@export var stick_degrees_per_second := 160.0
@export var mouse_degrees_per_pixel := 0.15
@export var min_pitch_deg := -60.0
@export var max_pitch_deg := 30.0
@export var blend_speed := 8.0

var two_shot_target: Node3D   # Talk (spec 4.5): frame the player and the NPC
var sensitivity := 1.0
var invert_y := false
var yaw := 0.0
var pitch := deg_to_rad(-15.0)

var _target_length := 4.0
var _target_height := 1.95

@onready var pitch_node: Node3D = $Pitch
@onready var spring: SpringArm3D = $Pitch/SpringArm3D
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D


func setup(config: PlayerConfig, body: CollisionObject3D) -> void:
	_target_length = config.spring_length_standing
	_target_height = config.eye_height_standing
	spring.spring_length = _target_length
	pitch_node.position.y = _target_height
	spring.add_excluded_object(body.get_rid())


func set_ducking(config: PlayerConfig, ducking: bool) -> void:
	_target_length = config.spring_length_ducking if ducking else config.spring_length_standing
	_target_height = config.eye_height_ducking if ducking else config.eye_height_standing


## Talk two-shot (spec 4.5): side-on to the line between the player and the target, so both
## are in frame. Returns the yaw the rig blends toward.
func two_shot_yaw(player_pos: Vector3) -> float:
	var d := two_shot_target.global_position - player_pos
	d.y = 0.0
	if d.length() < 0.01:
		return yaw
	var f := Vector3(d.z, 0.0, -d.x).normalized()
	return atan2(-f.x, -f.z)


func apply_input(f: InputFrame, delta: float, facing_yaw: float) -> void:
	if is_instance_valid(two_shot_target):
		var k := 1.0 - exp(-delta / 0.1)   # ~95% of the way in 0.3 s
		yaw = lerp_angle(yaw, two_shot_yaw(get_parent().global_position), k)
		pitch = lerpf(pitch, deg_to_rad(-10.0), k)
		rotation = Vector3(0.0, yaw, 0.0)
		pitch_node.rotation = Vector3(pitch, 0.0, 0.0)
		spring.spring_length = lerpf(spring.spring_length, _target_length + 1.0, k)
		return
	var y_sign := -1.0 if invert_y else 1.0
	yaw -= deg_to_rad(f.look.x * stick_degrees_per_second * delta + f.look_mouse.x * mouse_degrees_per_pixel) * sensitivity
	pitch -= deg_to_rad(f.look.y * stick_degrees_per_second * delta + f.look_mouse.y * mouse_degrees_per_pixel) * sensitivity * y_sign
	pitch = clampf(pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	if f.camera_reset_pressed:
		yaw = facing_yaw
	rotation = Vector3(0.0, yaw, 0.0)
	pitch_node.rotation = Vector3(pitch, 0.0, 0.0)
	var t := clampf(blend_speed * delta, 0.0, 1.0)
	spring.spring_length = lerpf(spring.spring_length, _target_length, t)
	pitch_node.position.y = lerpf(pitch_node.position.y, _target_height, t)


## World-space horizontal direction for a move vector (x right, y forward-negative),
## relative to the camera yaw. Length is at most 1.
func move_direction(move: Vector2) -> Vector3:
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var dir := right * move.x + forward * -move.y
	return dir.limit_length(1.0)
