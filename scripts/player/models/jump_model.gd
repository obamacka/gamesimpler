## Jump kinematics and timers (spec 1.4, 4.2, 4.2.1): coyote time, jump buffer and the
## single air jump. Pure logic; PlayerController feeds it floor state and presses.
class_name JumpModel
extends RefCounted

var gravity := 24.0
var jump_velocity := 7.9
var double_jump_velocity := 7.6
var coyote_time := 0.12
var buffer_time := 0.15
var max_fall_speed := 20.0
var max_air_jumps := 1

var coyote_left := 0.0
var buffer_left := 0.0
var air_jumps_left := 1


func configure(cfg: JumpConfig) -> void:
	gravity = cfg.gravity
	jump_velocity = cfg.jump_velocity
	double_jump_velocity = cfg.double_jump_velocity
	coyote_time = cfg.coyote_time
	buffer_time = cfg.buffer_time
	max_fall_speed = cfg.max_fall_speed
	air_jumps_left = max_air_jumps


static func apex_height(velocity: float, g: float) -> float:
	return velocity * velocity / (2.0 * g)


static func velocity_for_height(height: float, g: float) -> float:
	return sqrt(2.0 * g * height)


## Advance timers by `delta`.
func tick(delta: float) -> void:
	coyote_left = maxf(0.0, coyote_left - delta)
	buffer_left = maxf(0.0, buffer_left - delta)


## Player walked or fell off a ledge without jumping: start coyote time.
## The double jump stays available (spec 4.2).
func left_floor_without_jump() -> void:
	coyote_left = coyote_time
	air_jumps_left = max_air_jumps


func landed() -> void:
	coyote_left = 0.0
	air_jumps_left = max_air_jumps


## A press that could not jump right now is remembered for `buffer_time`.
func buffer_press() -> void:
	buffer_left = buffer_time


func is_buffered() -> bool:
	return buffer_left > 0.0


## Ground jump (also used during coyote time). Returns the new vertical velocity.
func consume_ground_jump() -> float:
	coyote_left = 0.0
	buffer_left = 0.0
	air_jumps_left = max_air_jumps
	return jump_velocity


func can_air_jump() -> bool:
	return air_jumps_left > 0


## Air jump sets (does not add) the vertical velocity. Returns it.
func consume_air_jump() -> float:
	assert(air_jumps_left > 0)
	air_jumps_left -= 1
	buffer_left = 0.0
	return double_jump_velocity


## Gravity step for a vertical velocity, clamped to max fall speed.
func apply_gravity(vy: float, delta: float) -> float:
	return maxf(vy - gravity * delta, -max_fall_speed)
