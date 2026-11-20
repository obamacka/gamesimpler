## Player tuning (spec 1.4). Instance: res://resources/config/player_config.tres
class_name PlayerConfig
extends Resource

@export var standing_height := 1.70   # rev 3.11 (spec 1.4): 2 free voxels
@export var ducking_height := 0.90    # fits 1-voxel crawl spaces
@export var radius := 0.30
@export var walk_speed := 2.2
@export var run_speed := 5.0
@export var duck_speed := 1.2
@export var ground_accel := 30.0
@export var eye_height_standing := 1.55
@export var eye_height_ducking := 0.75
@export var spring_length_standing := 4.0
@export var spring_length_ducking := 2.5
@export var reach_from_camera := 4.5
@export var reach_from_player := 3.0
## Character look until a character creator exists (spec 11.6, owner review).
@export var body: StringName = &"FEMALE"
@export var hair := "Hair_SimpleParted"
