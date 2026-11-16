## Rolls a LootTableDef with a seeded stream (spec 3.4). Coins are returned as item "coins".
class_name LootRoller
extends RefCounted


static func roll(table: LootTableDef, rng: RngStreams, stream: String = "loot") -> Array:
	var out: Array = []
	if table == null:
		return out
	for g in table.guaranteed:
		out.append({"item": StringName(g["item"]), "qty": int(g["qty"])})
	if table.entries.is_empty():
		return out
	var weights := table.entries.map(func(e): return int(e.get("weight", 1)))
	for i in table.rolls:
		var e: Dictionary = table.entries[rng.weighted_index(stream, weights)]
		var qty := rng.randi_range(stream, int(e.get("min", 1)), int(e.get("max", 1)))
		if qty > 0:
			out.append({"item": StringName(e["item"]), "qty": qty})
	return _merge(out)


static func _merge(drops: Array) -> Array:
	var by_item := {}
	var order: Array = []
	for d in drops:
		if not by_item.has(d["item"]):
			by_item[d["item"]] = 0
			order.append(d["item"])
		by_item[d["item"]] += d["qty"]
	return order.map(func(i): return {"item": i, "qty": by_item[i]})
