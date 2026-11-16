## Pet care rules (spec 3.6, 7.1). Pure. State: {"pet_uid", "species_id", "name",
## "color_variant", "happiness", "fed_day", "pat_day", "found_day", "accessories": {slot: stack|null}}.
## No starvation or neglect: happiness drifts toward 60 and never drops below 40.
class_name PetModel
extends RefCounted

const NOT_FOOD := &"not_pet_food"
const NO_ITEM := &"no_item"

var cfg: Dictionary = {}


func _init(config: Dictionary = {}) -> void:
	cfg = config


func floor_value() -> int:
	return int(cfg.get("happiness_floor", 40))


func new_pet(uid: String, species: StringName, variant: int, pet_name: String) -> Dictionary:
	return {"pet_uid": uid, "species_id": String(species), "name": pet_name, "color_variant": clampi(variant, 0, 2),
		"happiness": int(cfg.get("happiness_start", 70)), "fed_day": 0, "pat_day": 0, "found_day": 0,
		"accessories": {"HEAD": null, "NECK": null, "BODY": null}}


func _set_h(pet: Dictionary, v: int) -> int:
	var before := int(pet["happiness"])
	pet["happiness"] = clampi(v, floor_value(), 100)
	return int(pet["happiness"]) - before


## Pat: the first pat of the day gives pat_bonus, later pats pat_repeat. Returns the change.
func pat(pet: Dictionary, day: int) -> int:
	var bonus := int(cfg.get("pat_bonus", 5)) if int(pet["pat_day"]) != day else int(cfg.get("pat_repeat", 1))
	pet["pat_day"] = day
	return _set_h(pet, int(pet["happiness"]) + bonus)


static func is_favorite(item: ItemDef, sp: PetSpeciesDef) -> bool:
	return item.tags.any(func(t): return t in sp.favorite_food_tags)


## Accepts PET_FOOD, or FOOD tagged as a species favorite. Returns {"ok", "reason", "gain"}.
## Favorite doubles; a second feed on the same day has half effect (K7).
func feed(pet: Dictionary, item: ItemDef, sp: PetSpeciesDef, day: int) -> Dictionary:
	if item == null or item.food == null:
		return {"ok": false, "reason": NOT_FOOD, "gain": 0}
	var fav := is_favorite(item, sp)
	if not (item.category == &"PET_FOOD" or (item.category == &"FOOD" and fav)):
		return {"ok": false, "reason": NOT_FOOD, "gain": 0}
	var amount := item.food.pet_happiness * (2 if fav else 1)
	if int(pet["fed_day"]) == day:
		amount /= 2
	pet["fed_day"] = day
	return {"ok": true, "reason": &"", "gain": _set_h(pet, int(pet["happiness"]) + amount)}


## Daily drift toward the target (never past it), clamped to the floor.
func drift(pet: Dictionary) -> void:
	var target := int(cfg.get("drift_target", 60))
	var step := int(cfg.get("drift_step", 5))
	var h := int(pet["happiness"])
	if h > target:
		h = maxi(target, h - step)
	elif h < target:
		h = mini(target, h + step)
	_set_h(pet, h)


## Once-daily find at >= threshold. Returns the item id or &"".
func daily_find(pet: Dictionary, day: int, rng: RngStreams) -> StringName:
	var items: Array = cfg.get("find_items", [])
	if int(pet["happiness"]) < int(cfg.get("find_threshold", 80)) or int(pet["found_day"]) == day or items.is_empty():
		return &""
	pet["found_day"] = day
	return StringName(items[rng.randi_range("pet", 0, items.size() - 1)])
