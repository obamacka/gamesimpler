## Picks the care letter for a sleep transition (spec 6.2).
## exhausted: snack pool unless a snack already arrived on the day the player collapsed
## (`current_day == last_snack_day`), else the repeat pool. Exhausting every day therefore
## gives a snack at most every other time (known issue 12).
## late_night: no-snack pool. bed: no letter.
class_name CareLetterModel
extends RefCounted


static func pool_for(reason: StringName, current_day: int, last_snack_day: int) -> StringName:
	match reason:
		&"exhausted":
			return &"pool_care_exhausted" if last_snack_day != current_day else &"pool_care_exhausted_repeat"
		&"late_night":
			return &"pool_care_late_night"
	return &""


static func pick(pool: Array[MailTemplateDef], rng: RngStreams) -> MailTemplateDef:
	if pool.is_empty():
		return null
	return pool[rng.randi_range("mail_pool", 0, pool.size() - 1)]
