## Stamina (spec 6.1). Clamped at 0; depletion is edge-triggered; the action that reaches 0
## still lands (callers allow any costed action while current > 0).
class_name StaminaModel
extends RefCounted

var base_max := 100
var max_bonus_cap := 50
var bonus := 0
var current := 100
var low_thresholds_pct: Array[int] = [25, 10]
var _fired_today: Dictionary = {}


func configure(cfg: StaminaConfig) -> void:
	base_max = cfg.base_max
	max_bonus_cap = cfg.max_bonus_cap
	low_thresholds_pct = cfg.low_thresholds_pct.duplicate()
	current = max_value()


func max_value() -> int:
	return base_max + mini(bonus, max_bonus_cap)


func can_act() -> bool:
	return current > 0


## Returns {"spent": int, "depleted_now": bool, "low_crossed": Array[int] (percent levels)}.
func spend(amount: int) -> Dictionary:
	if current <= 0 or amount <= 0:
		return {"spent": 0, "depleted_now": false, "low_crossed": []}
	var before := current
	current = maxi(0, current - amount)
	var crossed: Array[int] = []
	for pct in low_thresholds_pct:
		var level := max_value() * pct / 100
		if before > level and current <= level and not _fired_today.has(pct):
			_fired_today[pct] = true
			crossed.append(pct)
	return {"spent": before - current, "depleted_now": before > 0 and current == 0, "low_crossed": crossed}


func restore(amount: int) -> int:
	var before := current
	current = mini(max_value(), current + maxi(0, amount))
	return current - before


func refill() -> void:
	current = max_value()


func new_day() -> void:
	_fired_today.clear()


func to_dict() -> Dictionary:
	return {"stamina": current, "max_stamina_bonus": bonus}


func from_dict(d: Dictionary) -> void:
	bonus = int(d.get("max_stamina_bonus", 0))
	current = clampi(int(d.get("stamina", max_value())), 0, max_value())
