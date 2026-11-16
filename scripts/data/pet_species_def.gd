## Pet species (spec 3.4, 4.6, 7.1).
class_name PetSpeciesDef
extends Resource

@export var id: StringName
@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var follow_distance := 2.5
@export var teleport_distance := 20.0
@export var idle_after := 2.0
@export var wander_after := 6.0
@export var wander_radius := 4.0
@export var accessory_bones: Dictionary = {"HEAD": "head", "NECK": "neck", "BODY": "body"}
@export var favorite_food_tags: Array[StringName] = []
@export var variants: Array[Color] = []
@export var size := Vector3(0.5, 0.6, 0.9)
