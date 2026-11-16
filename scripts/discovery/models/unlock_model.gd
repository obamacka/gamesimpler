## Unlocked ids by kind: recipes, dyes, stickers, emotes, outfits, instruments (spec 3.5 `unlocks`).
class_name UnlockModel
extends RefCounted

const KIND_KEYS := {&"BLUEPRINT": "recipes", &"DYE": "dyes", &"STICKER": "stickers", &"EMOTE": "emotes", &"OUTFIT": "outfits", &"INSTRUMENT": "instruments"}

var unlocked: Dictionary = {}   # String key -> Dictionary id -> true


func _key(kind: StringName) -> String:
	return KIND_KEYS.get(kind, String(kind).to_lower())


## Returns true if newly unlocked.
func grant(kind: StringName, id: StringName) -> bool:
	var k := _key(kind)
	if not unlocked.has(k):
		unlocked[k] = {}
	if unlocked[k].has(id):
		return false
	unlocked[k][id] = true
	return true


func is_unlocked(kind: StringName, id: StringName) -> bool:
	return unlocked.get(_key(kind), {}).has(id)


func to_dict() -> Dictionary:
	var d := {}
	for k in unlocked:
		var ids: Array = unlocked[k].keys().map(func(i): return String(i))
		ids.sort()
		d[k] = ids
	return d


func from_dict(d: Dictionary) -> void:
	unlocked.clear()
	for k in d:
		unlocked[String(k)] = {}
		for id in d[k]:
			unlocked[String(k)][StringName(id)] = true
