## Stamina tuning (spec 6.1).
class_name StaminaConfig
extends Resource

@export var base_max := 100
@export var max_bonus_cap := 50
@export var low_thresholds_pct: Array[int] = [25, 10]
@export var sit_regen_per_sec := 0.5
@export var forage_cost := 1
