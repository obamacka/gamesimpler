## Jump tuning (spec 1.4). Instance: res://resources/config/jump_config.tres
class_name JumpConfig
extends Resource

@export var gravity := 24.0
@export var jump_velocity := 7.9           # apex 1.30 m
@export var double_jump_velocity := 7.6    # set, not added: +1.20 m
@export var coyote_time := 0.12
@export var buffer_time := 0.15
@export var air_control := 0.8
@export var max_fall_speed := 20.0
