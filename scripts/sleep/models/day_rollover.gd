## Ordered day pipeline (spec 6.2). Never relies on signal connection order: services
## register named steps and run() calls them in ORDER. Unregistered steps are skipped.
class_name DayRollover
extends RefCounted

const ORDER: Array[StringName] = [
	&"clock", &"world_respawn", &"terrain_reset", &"farm_growth",
	&"restock", &"pet_reset", &"mail_deliver", &"day_started",
]

var _steps: Dictionary = {}   # StringName -> Callable(day)
var last_run: Array[StringName] = []


func register(step: StringName, fn: Callable) -> void:
	assert(step in ORDER, "DayRollover: unknown step %s" % step)
	_steps[step] = fn


func run(day: int) -> void:
	last_run.clear()
	for step in ORDER:
		if _steps.has(step):
			_steps[step].call(day)
			last_run.append(step)
