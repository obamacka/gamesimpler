## Mine: dig voxels or chop timber (spec 4.3). Timing lives in MineModel.
extends PlayerState

var model := MineModel.new()


func enter(_msg: Dictionary = {}) -> void:
	player.context.mine_done = false
	var data := player.equipped_tool_data()
	model.start(data.strike_interval_sec if data else 0.5)


func physics_tick(delta: float, f: InputFrame) -> void:
	var ev := model.tick(delta, f.use_held, player.mine_target_valid(), player.context.exhaustion_pending)
	if ev == &"strike":
		model.report_strike(player.perform_strike())
	player.context.mine_done = model.is_done()


func locks_tool() -> bool:
	return model.phase != MineModel.Phase.READY and not model.is_done()


func move_speed() -> float:
	return 0.0
