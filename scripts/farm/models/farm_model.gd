## Farming rules (spec 10.2, 10.5, D20 to D23). Pure. Keys are "zone/x,y,z".
## Soil cells hold farmland; a crop lives in the cell above its soil. Wetness is tracked per
## soil cell as the day it was watered, never as a voxel edit (spec 10.2).
class_name FarmModel
extends RefCounted

const NOT_FARMABLE := &"not_farmable"
const NOT_SOIL := &"not_soil"
const NO_ROOM := &"no_room"
const PROTECTED := &"protected"
const NOT_TILLED := &"not_tilled"
const OCCUPIED := &"occupied"
const NO_CROP := &"no_crop"
const ALREADY := &"already_watered"
const EMPTY_CAN := &"empty_can"
const NOT_RIPE := &"not_ripe"

var tilled: Dictionary = {}       # soil key -> true
var crops: Dictionary = {}        # crop key -> {"crop_id", "growth_days", "planted_day", "harvests"}
var wet: Dictionary = {}          # soil key -> day watered
var sprinklers: Dictionary = {}   # sprinkler key -> true (sprinkler sits at crop level)
var can_capacity := 20
var can_water := 20
var sprinkler_radius := 1


func configure(cfg: FarmConfig) -> void:
	can_capacity = cfg.can_capacity
	can_water = cfg.can_capacity
	sprinkler_radius = cfg.sprinkler_radius


static func key(zone: StringName, cell: Vector3i) -> String:
	return "%s/%d,%d,%d" % [zone, cell.x, cell.y, cell.z]


static func parse_key(k: String) -> Array:
	var zone := k.get_base_dir()
	var p := k.get_file().split(",")
	return [StringName(zone), Vector3i(int(p[0]), int(p[1]), int(p[2]))]


## D22: owned plots and the starter garden only; soil must be top-exposed grass or dirt
## with 2 free cells above.
static func farmable_reason(material_id: StringName, free_above: int, in_owned_plot: bool, protected: bool) -> StringName:
	if protected:
		return PROTECTED
	if not in_owned_plot:
		return NOT_FARMABLE
	if not (material_id in [&"mat_grass", &"mat_dirt"]):
		return NOT_SOIL
	if free_above < 2:
		return NO_ROOM
	return &""


func mark_tilled(zone: StringName, soil: Vector3i) -> void:
	tilled[key(zone, soil)] = true


func untill(zone: StringName, soil: Vector3i) -> void:
	tilled.erase(key(zone, soil))
	wet.erase(key(zone, soil))


func is_tilled(zone: StringName, soil: Vector3i) -> bool:
	return tilled.has(key(zone, soil))


func crop_at(zone: StringName, crop_cell: Vector3i) -> Dictionary:
	return crops.get(key(zone, crop_cell), {})


func can_plant(zone: StringName, soil: Vector3i) -> StringName:
	if not is_tilled(zone, soil):
		return NOT_TILLED
	if crops.has(key(zone, soil + Vector3i.UP)):
		return OCCUPIED
	return &""


func plant(zone: StringName, soil: Vector3i, crop_id: StringName, day: int) -> String:
	var k := key(zone, soil + Vector3i.UP)
	crops[k] = {"crop_id": String(crop_id), "growth_days": 0, "planted_day": day, "harvests": 0}
	return k


func is_watered_today(zone: StringName, soil: Vector3i, day: int) -> bool:
	return int(wet.get(key(zone, soil), -1)) == day


## Watering the same soil twice in a day is a no-op that spends no water (spec 10.5).
func water(zone: StringName, soil: Vector3i, day: int) -> StringName:
	if not is_tilled(zone, soil):
		return NOT_TILLED
	if is_watered_today(zone, soil, day):
		return ALREADY
	if can_water <= 0:
		return EMPTY_CAN
	can_water -= 1
	wet[key(zone, soil)] = day
	return &""


func refill() -> void:
	can_water = can_capacity


func place_sprinkler(zone: StringName, cell: Vector3i) -> String:
	var k := key(zone, cell)
	sprinklers[k] = true
	return k


## Rollover to `day` (spec 10.5): sprinklers water their neighbors for yesterday, then every
## crop whose soil was watered on day - 1 grows one day. Crops never wilt or die (D23).
## Returns [{"key", "stage"}] for crops that reached a new stage.
func daily_growth(day: int, crop_defs: Dictionary) -> Array:
	for sk in sprinklers:
		var p := parse_key(sk)
		for dx in range(-sprinkler_radius, sprinkler_radius + 1):
			for dz in range(-sprinkler_radius, sprinkler_radius + 1):
				if dx == 0 and dz == 0:
					continue
				var soil: Vector3i = p[1] + Vector3i(dx, -1, dz)
				var soil_key := key(p[0], soil)
				if tilled.has(soil_key) and int(wet.get(soil_key, -1)) < day - 1:
					wet[soil_key] = day - 1
	var grew: Array = []
	for ck in crops:
		var c: Dictionary = crops[ck]
		var p := parse_key(ck)
		var soil_key := key(p[0], p[1] + Vector3i.DOWN)
		if int(wet.get(soil_key, -1)) != day - 1:
			continue
		var def: CropDef = crop_defs[StringName(c["crop_id"])]
		if def.is_ripe(int(c["growth_days"])):
			continue
		var before := def.stage_for(int(c["growth_days"]))
		c["growth_days"] = int(c["growth_days"]) + 1
		var after := def.stage_for(int(c["growth_days"]))
		if after != before:
			grew.append({"key": ck, "stage": after})
	return grew


## Harvests a ripe crop. Returns {"ok": bool, "reason", "crop_id", "qty", "seeds"}.
func harvest(zone: StringName, crop_cell: Vector3i, def: CropDef, rng: RngStreams) -> Dictionary:
	var k := key(zone, crop_cell)
	var c: Dictionary = crops.get(k, {})
	if c.is_empty():
		return {"ok": false, "reason": NO_CROP}
	if not def.is_ripe(int(c["growth_days"])):
		return {"ok": false, "reason": NOT_RIPE}
	var qty := rng.randi_range("loot", def.yield_min, def.yield_max)
	var seeds := 1 if def.seed_return_pct > 0 and rng.chance("loot", def.seed_return_pct) else 0
	if def.regrow_stage >= 0:
		c["growth_days"] = def.days_at_stage(def.regrow_stage)
		c["harvests"] = int(c["harvests"]) + 1
	else:
		crops.erase(k)
	return {"ok": true, "reason": &"", "crop_id": def.id, "qty": qty, "seeds": seeds}


func to_dict() -> Dictionary:
	var t := {}
	for k in tilled:
		var p := parse_key(k)
		var z := String(p[0])
		if not t.has(z):
			t[z] = []
		var c: Vector3i = p[1]
		t[z].append("%d,%d,%d" % [c.x, c.y, c.z])
	for z in t:
		t[z].sort()
	var cr := {}
	for k in crops:
		cr[k] = crops[k].duplicate()
	var w := {}
	for k in wet:
		w[k] = int(wet[k])
	var sp: Array = sprinklers.keys()
	sp.sort()
	return {"tilled": t, "crops": cr, "wet": w, "sprinklers": sp, "watering_can": {"water": can_water}}


func from_dict(d: Dictionary) -> void:
	tilled.clear(); crops.clear(); wet.clear(); sprinklers.clear()
	var t: Dictionary = d.get("tilled", {})
	for z in t:
		for c in t[z]:
			tilled["%s/%s" % [z, c]] = true
	for k in d.get("crops", {}):
		var c: Dictionary = d["crops"][k]
		crops[k] = {"crop_id": String(c["crop_id"]), "growth_days": int(c["growth_days"]), "planted_day": int(c["planted_day"]), "harvests": int(c.get("harvests", 0))}
	for k in d.get("wet", {}):
		wet[k] = int(d["wet"][k])
	for k in d.get("sprinklers", []):
		sprinklers[String(k)] = true
	can_water = int(d.get("watering_can", {}).get("water", can_capacity))
