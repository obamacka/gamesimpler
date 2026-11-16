## Museum donations, cases and trophies (spec 6.5). Pure apart from reading Database.
## Guard order: not_collectible, already_donated (before any inventory change),
## not_in_inventory. Exactly one item is removed, plain stacks first.
class_name MuseumModel
extends RefCounted

const NOT_COLLECTIBLE := &"not_collectible"
const ALREADY := &"already_donated"
const NOT_IN_INVENTORY := &"not_in_inventory"

var donated: Dictionary = {}          # String item id -> day (int)
var cases_unlocked: Array[String] = []
var trophies_unlocked: Array[String] = []
var rewards_granted: Array[String] = []


func is_donated(item_id: StringName) -> bool:
	return donated.has(String(item_id))


## Returns {"ok", "reason", "category", "cases": [...], "trophies": [...]}.
func donate(item_id: StringName, inv: InventoryModel, day: int) -> Dictionary:
	var it := Database.item(item_id)
	if it == null or it.collection == null:
		return {"ok": false, "reason": NOT_COLLECTIBLE}
	if is_donated(item_id):
		return {"ok": false, "reason": ALREADY}
	if inv.count(item_id) < 1:
		return {"ok": false, "reason": NOT_IN_INVENTORY}
	inv.remove(item_id, 1)   # InventoryModel.remove takes plain stacks first
	donated[String(item_id)] = day
	var newly := evaluate()
	return {"ok": true, "reason": &"", "category": it.collection.category, "cases": newly["cases"], "trophies": newly["trophies"]}


func _count(pred: Callable) -> int:
	var n := 0
	for id in donated:
		var it := Database.item(StringName(id))
		if it and it.collection and pred.call(it.collection):
			n += 1
	return n


func _set_complete(set_id: StringName) -> bool:
	var members: Array = Database.collectibles().filter(func(it): return it.collection.set_id == set_id)
	return not members.is_empty() and members.all(func(it): return is_donated(it.id))


func case_satisfied(c: Dictionary) -> bool:
	if c["unlock_rule"] == &"SET_COMPLETE":
		return _set_complete(c["set_id"])
	return _count(func(e): return e.case_id == c["id"]) >= int(c["count"])


func trophy_satisfied(t: Dictionary) -> bool:
	match t["condition"]:
		&"TOTAL_COUNT":
			return donated.size() >= int(t["count"])
		&"CATEGORY_COUNT":
			return _count(func(e): return e.category == t["category"]) >= int(t["count"])
		&"SET_COMPLETE":
			return _set_complete(t["set_id"])
		&"ALL_COMPLETE":
			return Database.collectibles().all(func(it): return is_donated(it.id))
	return false


## Unlocks every newly satisfied case and trophy once. Returns their ids.
func evaluate() -> Dictionary:
	var cases: Array = []
	var trophies: Array = []
	for c in Database.museum.cases:
		if not (String(c["id"]) in cases_unlocked) and case_satisfied(c):
			cases_unlocked.append(String(c["id"]))
			cases.append(c["id"])
	for t in Database.museum.trophies:
		if not (String(t["id"]) in trophies_unlocked) and trophy_satisfied(t):
			trophies_unlocked.append(String(t["id"]))
			trophies.append(t["id"])
	return {"cases": cases, "trophies": trophies}


## Trophies unlocked but not yet rewarded (load reconcile and fresh unlocks alike).
func pending_rewards() -> Array:
	return trophies_unlocked.filter(func(t): return not (t in rewards_granted))


func to_dict() -> Dictionary:
	var d := {}
	for k in donated:
		d[k] = int(donated[k])
	return {"donated": d, "cases_unlocked": cases_unlocked.duplicate(), "trophies_unlocked": trophies_unlocked.duplicate(),
		"rewards_granted": rewards_granted.duplicate()}


func from_dict(d: Dictionary) -> void:
	donated.clear()
	for k in d.get("donated", {}):
		donated[String(k)] = int(d["donated"][k])
	cases_unlocked.assign((d.get("cases_unlocked", []) as Array).map(func(v): return String(v)))
	trophies_unlocked.assign((d.get("trophies_unlocked", []) as Array).map(func(v): return String(v)))
	rewards_granted.assign((d.get("rewards_granted", []) as Array).map(func(v): return String(v)))
