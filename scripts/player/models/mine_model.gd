## Mine sub-FSM timing (spec 4.3): Ready -> Windup -> Strike -> Recover -> (Windup | Retarget | Done).
class_name MineModel
extends RefCounted

enum Phase { READY, WINDUP, RECOVER, DONE }

var phase: Phase = Phase.READY
var interval := 0.5
var _t := 0.0
var _target_destroyed := false


func start(strike_interval: float) -> void:
	interval = maxf(0.1, strike_interval)
	phase = Phase.WINDUP
	_t = 0.0
	_target_destroyed = false


## Caller reports the outcome of the strike it just performed.
func report_strike(destroyed: bool) -> void:
	_target_destroyed = destroyed


## Returns &"strike" on the hit frame, &"done" when the cycle ends, &"" otherwise.
## `target_valid` means the current (or, after a destroy, the newly aimed) target is diggable.
func tick(delta: float, use_held: bool, target_valid: bool, exhaustion_pending: bool) -> StringName:
	match phase:
		Phase.WINDUP:
			if not target_valid:
				phase = Phase.DONE
				return &"done"
			_t += delta
			if _t >= interval * 0.5:
				_t = 0.0
				phase = Phase.RECOVER
				return &"strike"
		Phase.RECOVER:
			_t += delta
			if _t >= interval * 0.5:
				_t = 0.0
				if exhaustion_pending or not use_held:
					phase = Phase.DONE
					return &"done"
				if _target_destroyed and not target_valid:
					phase = Phase.DONE
					return &"done"
				_target_destroyed = false
				phase = Phase.WINDUP
	return &""


func is_done() -> bool:
	return phase == Phase.DONE
