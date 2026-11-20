## Crop (spec 10.3). Stage = number of completed `days_per_stage` entries; ripe when all are done.
class_name CropDef
extends Resource

@export var id: StringName
@export var seed_item_id: StringName
@export var harvest_item_id: StringName
@export var days_per_stage: Array[int] = [1, 1, 1]
@export var regrow_stage := -1      # -1 = single harvest
@export var yield_min := 1
@export var yield_max := 1
@export var seed_return_pct := 0
@export var color := Color.GREEN
## Stage models (spec 11.9): {"stages": [3 scene paths], "ripe": path, "height": metres}.
@export var models: Dictionary = {}


func has_models() -> bool:
	return not models.is_empty()


## Scene for a growth stage (0 .. stage_count - 1) or the ripe model.
func model_for(stage: int, is_ripe_now: bool) -> String:
	if not has_models():
		return ""
	if is_ripe_now:
		return models["ripe"]
	var stages: Array = models["stages"]
	return stages[clampi(stage * stages.size() / maxi(stage_count(), 1), 0, stages.size() - 1)]


func stage_count() -> int:
	return days_per_stage.size()


func days_to_ripe() -> int:
	var t := 0
	for d in days_per_stage:
		t += d
	return t


func stage_for(growth_days: int) -> int:
	var acc := 0
	for i in days_per_stage.size():
		acc += days_per_stage[i]
		if growth_days < acc:
			return i
	return days_per_stage.size()


func is_ripe(growth_days: int) -> bool:
	return growth_days >= days_to_ripe()


## Growth days at the start of `stage` (used to regrow).
func days_at_stage(stage: int) -> int:
	var acc := 0
	for i in mini(stage, days_per_stage.size()):
		acc += days_per_stage[i]
	return acc
