## Jump (rising). Entry applies the ground or air jump velocity (spec 4.2).
extends PlayerState



func enter(msg: Dictionary = {}) -> void:
	match msg.get("effect", &""):
		PlayerTransitionTable.FX_AIR_JUMP:
			player.velocity.y = player.jump.consume_air_jump()
			player.jumped_this_tick = true
		PlayerTransitionTable.FX_GROUND_JUMP, PlayerTransitionTable.FX_STAND_UP:
			player.velocity.y = player.jump.consume_ground_jump()
			player.jumped_this_tick = true
			player.capture_air_speed()
			player.note_manual_or_auto_jump(msg.get("auto", false))


func is_airborne() -> bool:
	return true
