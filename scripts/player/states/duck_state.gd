## Duck: swaps to the 1.30 m capsule and lowers the camera (spec 4.2).
extends PlayerState


func enter(_msg: Dictionary = {}) -> void:
	player.set_ducking(true)


func exit() -> void:
	player.set_ducking(false)


func move_speed() -> float:
	return player.config.duck_speed
