## Save JSON codec (spec 3.5, P6.8). Pure: parse, migrate, validate structure, cast integers
## (rejecting non-integral values), sanitize content. Encoding sorts keys so equal sessions
## produce byte-identical files.
class_name SaveCodec
extends RefCounted

const CURRENT := 2
const PARSE := &"parse_error"
const STRUCTURAL := &"structural"
const NON_INTEGRAL := &"non_integral"
const TOO_NEW := &"newer_version"

const SECTIONS := {
	"rng": TYPE_DICTIONARY, "clock": TYPE_DICTIONARY, "player": TYPE_DICTIONARY, "exhaustion": TYPE_DICTIONARY,
	"toolbelt": TYPE_DICTIONARY, "inventory": TYPE_DICTIONARY, "wallet": TYPE_DICTIONARY, "unlocks": TYPE_DICTIONARY,
	"terrain": TYPE_DICTIONARY, "world": TYPE_DICTIONARY, "discovery": TYPE_DICTIONARY, "mail": TYPE_DICTIONARY,
	"farm": TYPE_DICTIONARY, "housing": TYPE_DICTIONARY, "build": TYPE_DICTIONARY, "jobs": TYPE_DICTIONARY,
	"shops": TYPE_DICTIONARY, "npcs": TYPE_DICTIONARY, "pets": TYPE_ARRAY, "museum": TYPE_DICTIONARY,
	"collection": TYPE_DICTIONARY,
}
const NESTED := {
	"museum/donated": TYPE_DICTIONARY, "museum/cases_unlocked": TYPE_ARRAY, "museum/trophies_unlocked": TYPE_ARRAY,
	"museum/rewards_granted": TYPE_ARRAY, "collection/discovered": TYPE_ARRAY, "inventory/backpack": TYPE_ARRAY,
	"mail/inbox": TYPE_ARRAY, "mail/scheduled": TYPE_ARRAY, "build/pieces": TYPE_DICTIONARY,
}
const INT_PATHS := ["clock/day", "clock/minute", "wallet/coins", "player/stamina", "player/max_stamina_bonus",
	"exhaustion/last_snack_day", "exhaustion/count_total", "mail/next_mail_seq", "build/next_uid", "voxel/epoch"]

## version -> Callable(Dictionary) -> Dictionary producing version + 1. Applied in order.
static var MIGRATIONS := {1: migrate_1_to_2}


static func encode(d: Dictionary) -> String:
	return JSON.stringify(d, "\t", true)


## Returns {"ok", "error", "data", "notices": Array[StringName]}.
static func decode(text: String) -> Dictionary:
	var notices: Array = []
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(text) == OK else null   # parse() reports without logging engine errors
	if not (parsed is Dictionary):
		return {"ok": false, "error": PARSE, "data": {}, "notices": notices}
	var d: Dictionary = migrate(parsed)
	if int(d.get("schema_version", 0)) > CURRENT:
		return {"ok": false, "error": TOO_NEW, "data": {}, "notices": notices}
	var err := check_structure(d)
	if err != &"":
		return {"ok": false, "error": err, "data": {}, "notices": notices}
	err = cast_ints(d)
	if err != &"":
		return {"ok": false, "error": err, "data": {}, "notices": notices}
	sanitize(d, notices)
	return {"ok": true, "error": &"", "data": d, "notices": notices}


static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("schema_version", 1))
	while MIGRATIONS.has(v) and v < CURRENT:
		d = MIGRATIONS[v].call(d)
		v = int(d["schema_version"])
	return d


## v1 (Phases 2 to 5) -> v2: museum and collection sections, player transform defaults.
static func migrate_1_to_2(d: Dictionary) -> Dictionary:
	var o := d.duplicate(true)
	if not o.has("museum"):
		o["museum"] = {"donated": {}, "cases_unlocked": [], "trophies_unlocked": [], "rewards_granted": []}
	if not o.has("collection"):
		o["collection"] = {"discovered": []}
	var p: Dictionary = o.get("player", {})
	if not p.has("zone_id"):
		p["zone_id"] = String(Database.home_zone)
		p["position"] = [0.0, 0.0, 0.0]
		p["yaw"] = 0.0
	o["player"] = p
	o["schema_version"] = 2
	return o


static func _path_get(d: Dictionary, path: String) -> Variant:
	var cur: Variant = d
	for part in path.split("/"):
		if not (cur is Dictionary) or not cur.has(part):
			return null
		cur = cur[part]
	return cur


static func check_structure(d: Dictionary) -> StringName:
	for k in SECTIONS:
		if d.has(k) and typeof(d[k]) != SECTIONS[k]:
			return STRUCTURAL
	for path in NESTED:
		var v = _path_get(d, path)
		if v != null and typeof(v) != NESTED[path]:
			return STRUCTURAL
	return &""


static func _int_ok(v: Variant) -> bool:
	return v is int or (v is float and is_equal_approx(v, round(v)))


static func cast_ints(d: Dictionary) -> StringName:
	for path in INT_PATHS:
		var parts: PackedStringArray = path.split("/")
		var parent = _path_get(d, parts[0])
		if parent is Dictionary and parent.has(parts[1]):
			if not _int_ok(parent[parts[1]]):
				return NON_INTEGRAL
			parent[parts[1]] = int(parent[parts[1]])
	var donated = _path_get(d, "museum/donated")
	if donated is Dictionary:
		for k in donated:
			if not _int_ok(donated[k]):
				return NON_INTEGRAL
			donated[k] = int(donated[k])
	return &""


## Content sanitization (spec 3.5): never fails the load.
static func sanitize(d: Dictionary, notices: Array) -> void:
	var dropped := false
	var col: Dictionary = d.get("collection", {})
	var seen := {}
	var disc: Array = []
	for id in col.get("discovered", []):
		if not Database.items.has(StringName(id)):
			dropped = true
			continue
		if not seen.has(String(id)):
			seen[String(id)] = true
			disc.append(String(id))
	var mus: Dictionary = d.get("museum", {})
	var donated: Dictionary = mus.get("donated", {})
	for k in donated.keys():
		if not Database.items.has(StringName(k)) or Database.item(StringName(k)).collection == null:
			donated.erase(k)
			dropped = true
		elif not seen.has(String(k)):
			seen[String(k)] = true
			disc.append(String(k))
	disc.sort()
	if d.has("collection"):
		d["collection"]["discovered"] = disc
	for key in ["cases_unlocked", "trophies_unlocked", "rewards_granted"]:
		if mus.has(key):
			var u: Array = []
			for x in mus[key]:
				if not (String(x) in u):
					u.append(String(x))
			mus[key] = u
	var inv: Dictionary = d.get("inventory", {})
	var bp: Array = inv.get("backpack", [])
	for i in bp.size():
		if bp[i] is Dictionary and not Database.items.has(StringName(bp[i].get("item_id", ""))):
			bp[i] = null
			dropped = true
	var world: Dictionary = d.get("world", {})
	var chests: Dictionary = world.get("chests", {})
	for k in chests.keys():
		if not Database.zones.has(StringName(chests[k].get("zone", ""))):
			chests.erase(k)
	if dropped:
		push_warning("SaveCodec: unknown content ids were dropped from the save")
		notices.append(&"unknown_ids_dropped")
