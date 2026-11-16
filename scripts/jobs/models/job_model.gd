## Job ranks and XP (spec 3.4). Pure. rank = highest index whose threshold <= xp.
class_name JobModel
extends RefCounted


static func rank_for(def: JobDef, xp: int) -> int:
	var r := 0
	for i in def.ranks_xp.size():
		if xp >= def.ranks_xp[i]:
			r = i
	return r


## Adds XP to state {"rank", "xp"}; returns the number of ranks gained.
static func add_xp(def: JobDef, state: Dictionary, amount: int) -> int:
	var before := int(state.get("rank", 0))
	state["xp"] = int(state.get("xp", 0)) + maxi(0, amount)
	state["rank"] = rank_for(def, state["xp"])
	return int(state["rank"]) - before


static func next_threshold(def: JobDef, rank: int) -> int:
	return def.ranks_xp[rank + 1] if rank + 1 < def.ranks_xp.size() else -1
