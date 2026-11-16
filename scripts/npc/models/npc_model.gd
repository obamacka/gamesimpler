## NPC relationship state (spec 3.5 npcs). Pure. One per NPC:
## {"friendship": int, "met": bool, "gifted_day": int, "talked_day": int, "waved_day": int, "flags": []}
class_name NpcModel
extends RefCounted

const ALREADY_GIFTED := &"already_gifted"
const NOT_GIFTABLE := &"not_giftable"

var state: Dictionary = {}


func of(npc_id: StringName) -> Dictionary:
	var k := String(npc_id)
	if not state.has(k):
		state[k] = {"friendship": 0, "met": false, "gifted_day": 0, "talked_day": 0, "waved_day": 0, "flags": []}
	return state[k]


func _add(s: Dictionary, n: int, cfg: Dictionary) -> int:
	var before := int(s["friendship"])
	s["friendship"] = clampi(before + n, 0, int(cfg.get("max", 1000)))
	return int(s["friendship"]) - before


## First talk of the day adds `talk_daily`. Returns the friendship gained.
func talk(npc_id: StringName, day: int, cfg: Dictionary) -> int:
	var s := of(npc_id)
	s["met"] = true
	if int(s["talked_day"]) == day:
		return 0
	s["talked_day"] = day
	return _add(s, int(cfg.get("talk_daily", 5)), cfg)


## One gift per NPC per day; points by preference. Returns {"ok", "reason", "gain", "pref"}.
func gift(def: NpcDef, item: ItemDef, day: int, cfg: Dictionary) -> Dictionary:
	var s := of(def.id)
	if item == null or not item.giftable or item.category in [&"TOOL", &"KEY_ITEM"]:
		return {"ok": false, "reason": NOT_GIFTABLE, "gain": 0, "pref": &""}
	if int(s["gifted_day"]) == day:
		return {"ok": false, "reason": ALREADY_GIFTED, "gain": 0, "pref": &""}
	var pref := def.preference(item.id)
	s["gifted_day"] = day
	s["met"] = true
	var gain := _add(s, int(cfg.get("gift_" + String(pref), 0)), cfg)
	return {"ok": true, "reason": &"", "gain": gain, "pref": pref}


## First wave per NPC per day: +wave_daily (spec 7.4).
func wave(npc_id: StringName, day: int, cfg: Dictionary) -> int:
	var s := of(npc_id)
	if int(s["waved_day"]) == day:
		return 0
	s["waved_day"] = day
	return _add(s, int(cfg.get("wave_daily", 1)), cfg)


func hearts(npc_id: StringName) -> int:
	return int(of(npc_id)["friendship"]) / 100


func best_friend() -> StringName:
	var best := &""
	var best_f := 0
	var keys := state.keys()
	keys.sort()
	for k in keys:
		if int(state[k]["friendship"]) > best_f:
			best = StringName(k)
			best_f = int(state[k]["friendship"])
	return best


func to_dict() -> Dictionary:
	return state.duplicate(true)


func from_dict(d: Dictionary) -> void:
	state = {}
	for k in d:
		if not Database.npcs.has(StringName(k)):
			continue
		var s: Dictionary = d[k]
		state[String(k)] = {"friendship": int(s.get("friendship", 0)), "met": bool(s.get("met", false)), "gifted_day": int(s.get("gifted_day", 0)),
			"talked_day": int(s.get("talked_day", 0)), "waved_day": int(s.get("waved_day", 0)), "flags": (s.get("flags", []) as Array).duplicate()}
