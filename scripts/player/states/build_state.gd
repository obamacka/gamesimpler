## Build (spec 4.4): walk while building; the BuildController runs the sub-FSM.
extends PlayerState


func enter(msg: Dictionary = {}) -> void:
	if not player.build_active:
		player.build_active = true
		player.build_ctl.enter()


func physics_tick(delta: float, f: InputFrame) -> void:
	player.build_ctl.tick(delta, f, false)


func move_speed() -> float:
	return 0.0 if player.build_ctl.is_fastening() else player.config.walk_speed


func locks_tool() -> bool:
	return player.build_ctl.is_fastening()
