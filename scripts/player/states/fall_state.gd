## Fall (descending or walked off a ledge).
extends PlayerState



func enter(msg: Dictionary = {}) -> void:
	if msg.get("effect", &"") == PlayerTransitionTable.FX_CEILING:
		player.velocity.y = minf(player.velocity.y, 0.0)
	if msg.get("from", &"") != PlayerTransitionTable.JUMP:
		player.capture_air_speed()


func is_airborne() -> bool:
	return true
