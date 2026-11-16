## Kill plane or deep water (spec 6.3): returns the player to safe ground, no cost.
class_name SafetyVolume
extends Area3D


func _ready() -> void:
	collision_layer = 256   # layer 9 (safety)
	collision_mask = 2      # player
	monitoring = true
	body_entered.connect(func(b): if b.has_method("return_to_safe_ground"): b.return_to_safe_ground())
