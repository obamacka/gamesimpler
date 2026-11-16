## Picks the care letter for a sleep transition (spec 6.2).
## exhausted: snack pool if no snack was given on `new_day` yet, else the repeat pool.
## late_night: no-snack pool. bed: no letter.
class_name CareLetterModel
extends RefCounted


static func pool_for(reason: StringName, new_day: int, last_snack_day: int) -> StringName:
	match reason:
		&"exhausted":
			return &"pool_care_exhausted" if last_snack_day != new_day else &"pool_care_exhausted_repeat"
		&"late_night":
			return &"pool_care_late_night"
	return &""


static func pick(pool: Array[MailTemplateDef], rng: RngStreams) -> MailTemplateDef:
	if pool.is_empty():
		return null
	return pool[rng.randi_range("mail_pool", 0, pool.size() - 1)]
