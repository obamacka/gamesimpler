## Craft checks (spec 3.2, D4). Pure. Output space is checked after simulating the input
## removal on a copy, so a full backpack can still craft when inputs free a slot.
class_name CraftModel
extends RefCounted

const OK := &""
const LOCKED := &"locked"
const MISSING_INPUTS := &"missing_inputs"
const NO_COINS := &"not_enough_coins"
const NO_SPACE := &"no_space"
const WRONG_STATION := &"wrong_station"


## Returns {"reason": StringName, "missing": [{"item", "have", "need"}]}.
static func check(r: RecipeDef, inv: InventoryModel, coins: int, unlocked: bool, station: StringName = &"") -> Dictionary:
	var missing: Array = []
	for e in r.inputs:
		var have := inv.count(e["item"])
		if have < int(e["qty"]):
			missing.append({"item": e["item"], "have": have, "need": int(e["qty"])})
	var out := {"reason": OK, "missing": missing}
	if station != &"" and r.station != station and r.station != &"HAND":
		out["reason"] = WRONG_STATION
	elif not unlocked:
		out["reason"] = LOCKED
	elif not missing.is_empty():
		out["reason"] = MISSING_INPUTS
	elif coins < r.coin_cost:
		out["reason"] = NO_COINS
	elif not outputs_fit(r, inv):
		out["reason"] = NO_SPACE
	return out


static func outputs_fit(r: RecipeDef, inv: InventoryModel) -> bool:
	var sim := InventoryModel.new(inv.slots.size(), inv.max_stack_of)
	sim.from_dict(inv.to_dict())
	for e in r.inputs:
		sim.remove(e["item"], int(e["qty"]))
	for e in r.outputs:
		if sim.add(e["item"], int(e["qty"])) > 0:
			return false
	return true
