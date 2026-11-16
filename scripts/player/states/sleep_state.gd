## Sleep (spec 4.5): yawn (exhausted) or lie down, then hand control to SleepDirector.
## The FSM resets to Idle when EventBus.player_woke fires.
extends PlayerState

var reason: StringName = &"exhausted"
var _t := 0.0
var _started := false


func enter(msg: Dictionary = {}) -> void:
	reason = msg.get("reason", &"exhausted")
	if reason == &"" or reason == PlayerTransitionTable.FX_NONE:
		reason = &"exhausted"
	_t = 0.0
	_started = false


func physics_tick(delta: float, _f: InputFrame) -> void:
	if _started:
		return
	_t += delta
	if _t >= player.yawn_seconds:
		_started = true
		player.session().sleep.begin_sleep(reason)


func locks_tool() -> bool:
	return true
