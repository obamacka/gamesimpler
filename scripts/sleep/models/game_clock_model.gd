## In-game time (spec D6): 20 real minutes per day from 06:00 to 02:00, so one game minute
## per real second. `minute` counts from midnight of `day` and runs past 1440 until 02:00.
class_name GameClockModel
extends RefCounted

const MORNING := 360           # 06:00
const LATE_NIGHT := 1440 + 120 # 02:00 the next calendar day
const GAME_MINUTES_PER_SECOND := 1.0

var day := 1
var minute := MORNING
var _accum := 0.0
var _late_fired := false


## Advances time. Returns true once when 02:00 is reached.
func tick(delta: float) -> bool:
	_accum += delta * GAME_MINUTES_PER_SECOND
	while _accum >= 1.0:
		_accum -= 1.0
		minute += 1
	if minute >= LATE_NIGHT and not _late_fired:
		_late_fired = true
		return true
	return false


func set_time(d: int, m: int) -> void:
	day = d
	minute = m
	_accum = 0.0
	_late_fired = minute >= LATE_NIGHT


func set_morning(d: int) -> void:
	set_time(d, MORNING)


func to_dict() -> Dictionary:
	return {"day": day, "minute": minute}


func from_dict(d: Dictionary) -> void:
	set_time(int(d.get("day", 1)), int(d.get("minute", MORNING)))
