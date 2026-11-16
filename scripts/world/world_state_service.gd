## Fruit trees, timber, chests and dropped pickups (spec 1.8, 6.4, D8).
class_name WorldStateService
extends Node

signal pickup_requested(item_id: StringName, qty: int, position: Vector3)

var session: GameSession
var fruit: Dictionary = {}    # key -> {"def", "fruit", "regrow_day"}
var timber: Dictionary = {}   # key -> {"def", "hp", "chopped", "respawn_day"}
var chests: Dictionary = {}   # key -> {"cell": Array, "table", "zone", "opened"}
var _chest_seq := 0


func setup(s: GameSession) -> void:
	session = s


func register_fruit_tree(key: String, def_id: StringName) -> Dictionary:
	if not fruit.has(key):
		var def: FruitTreeDef = Database.fruit_trees[def_id]
		fruit[key] = {"def": String(def_id), "fruit": def.fruit_max, "regrow_day": 0}
	return fruit[key]


func fruit_count(key: String) -> int:
	return int(fruit.get(key, {}).get("fruit", 0))


## Picks every fruit. Returns the amount given (overflow drops as pickups at `at`).
func harvest_tree(key: String, at: Vector3) -> int:
	var st: Dictionary = fruit.get(key, {})
	if st.is_empty() or int(st["fruit"]) <= 0:
		return 0
	var def: FruitTreeDef = Database.fruit_trees[StringName(st["def"])]
	var qty := int(st["fruit"])
	st["fruit"] = 0
	st["regrow_day"] = session.day() + def.regrow_days
	give_drops([{"item": def.fruit_item_id, "qty": qty}], at)
	EventBus.tree_harvested.emit(key, qty)
	return qty


func register_timber(key: String, def_id: StringName) -> Dictionary:
	if not timber.has(key):
		var def: TimberTreeDef = Database.timber_trees[def_id]
		timber[key] = {"def": String(def_id), "hp": def.max_hp, "chopped": false, "respawn_day": 0}
	return timber[key]


func is_chopped(key: String) -> bool:
	return bool(timber.get(key, {}).get("chopped", true))


## One axe strike. Returns {"result": &"damaged" | &"felled" | &"gone", "hp_left": int}.
func chop(key: String, power: int, at: Vector3) -> Dictionary:
	var st: Dictionary = timber.get(key, {})
	if st.is_empty() or st["chopped"]:
		return {"result": &"gone", "hp_left": 0}
	st["hp"] = int(st["hp"]) - power
	if int(st["hp"]) > 0:
		return {"result": &"damaged", "hp_left": st["hp"]}
	var def: TimberTreeDef = Database.timber_trees[StringName(st["def"])]
	st["chopped"] = true
	st["respawn_day"] = session.day() + def.respawn_days
	give_drops(LootRoller.roll(Database.loot_tables.get(def.loot), session.rng), at)
	EventBus.tree_chopped.emit(key)
	return {"result": &"felled", "hp_left": 0}


func respawn_due(day: int) -> void:
	for key in fruit:
		var st: Dictionary = fruit[key]
		if int(st["fruit"]) == 0 and int(st["regrow_day"]) <= day:
			var def: FruitTreeDef = Database.fruit_trees[StringName(st["def"])]
			st["fruit"] = session.rng.randi_range("loot", def.fruit_min, def.fruit_max)
	for key in timber:
		var st: Dictionary = timber[key]
		if st["chopped"] and int(st["respawn_day"]) <= day:
			st["chopped"] = false
			st["hp"] = Database.timber_trees[StringName(st["def"])].max_hp
	# Deep Mine chests are per-day (D16); unopened ones vanish at rollover.
	for key in chests.keys():
		var z: TerrainZoneDef = Database.zones.get(StringName(chests[key]["zone"]))
		if z and z.kind == TerrainZoneDef.DEEP_MINE:
			chests.erase(key)


func spawn_chest(cell: Vector3i, zone_id: StringName) -> String:
	_chest_seq += 1
	var key := "%s/chest_%04d" % [zone_id, _chest_seq]
	var z: TerrainZoneDef = Database.zones.get(zone_id)
	var table: StringName = z.treasure_table if z and z.treasure_table != &"" else &"loot_chest_overworld"
	chests[key] = {"cell": [cell.x, cell.y, cell.z], "table": String(table), "zone": String(zone_id), "opened": false}
	EventBus.chest_spawned.emit(key, cell)
	return key


## Opens a chest: grants the reward, then removes the chest (spec 6.4). Returns the reward or {}.
func open_chest(key: String, at: Vector3) -> Dictionary:
	var st: Dictionary = chests.get(key, {})
	if st.is_empty():
		return {}
	var reward := DiscoveryModel.open_chest(Database.treasure_tables[StringName(st["table"])], session.unlocks.model, session.rng)
	match reward["kind"]:
		&"COINS":
			session.wallet.credit(reward["coins"])
		&"ITEM":
			give_drops([{"item": reward["item"], "qty": reward["qty"]}], at)
		_:
			session.unlocks.grant(reward["kind"], reward["id"])
	chests.erase(key)
	EventBus.chest_opened.emit(key, reward)
	return reward


## Gives drops: coins to the wallet, items to the inventory; overflow becomes pickups (K1).
func give_drops(drops: Array, at: Vector3) -> void:
	for d in drops:
		if d["item"] == &"coins" or String(d["item"]) == "coins":
			session.wallet.credit(int(d["qty"]))
			continue
		var overflow := session.inventory.add(StringName(d["item"]), int(d["qty"]))
		if overflow > 0:
			pickup_requested.emit(StringName(d["item"]), overflow, at)


func to_dict() -> Dictionary:
	var trees := {}
	for k in fruit:
		trees[k] = {"def": fruit[k]["def"], "fruit": int(fruit[k]["fruit"]), "regrow_day": int(fruit[k]["regrow_day"])}
	var t := {}
	for k in timber:
		t[k] = {"def": timber[k]["def"], "hp": int(timber[k]["hp"]), "chopped": bool(timber[k]["chopped"]), "respawn_day": int(timber[k]["respawn_day"])}
	var c := {}
	for k in chests:
		var z: TerrainZoneDef = Database.zones.get(StringName(chests[k]["zone"]))
		if z and z.kind == TerrainZoneDef.DEEP_MINE:
			continue   # D16: not saved
		c[k] = chests[k].duplicate(true)
	return {"trees": trees, "timber": t, "chests": c, "chest_seq": _chest_seq}


func from_dict(d: Dictionary) -> void:
	fruit.clear(); timber.clear(); chests.clear()
	for k in d.get("trees", {}):
		var s: Dictionary = d["trees"][k]
		fruit[k] = {"def": s["def"], "fruit": int(s["fruit"]), "regrow_day": int(s["regrow_day"])}
	for k in d.get("timber", {}):
		var s: Dictionary = d["timber"][k]
		timber[k] = {"def": s["def"], "hp": int(s["hp"]), "chopped": bool(s["chopped"]), "respawn_day": int(s["respawn_day"])}
	for k in d.get("chests", {}):
		var s: Dictionary = d["chests"][k]
		chests[k] = {"cell": (s["cell"] as Array).map(func(v): return int(v)), "table": s["table"], "zone": s["zone"], "opened": bool(s.get("opened", false))}
	_chest_seq = int(d.get("chest_seq", 0))
