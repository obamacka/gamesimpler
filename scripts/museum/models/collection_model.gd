## Collection Book discovery (spec 6.5). Pure. Key = item id; only collectibles count.
class_name CollectionModel
extends RefCounted

var discovered: Dictionary = {}   # String item id -> true


## Returns true the first time a collectible is seen.
func mark(item_id: StringName) -> bool:
	var it := Database.item(item_id)
	if it == null or it.collection == null or discovered.has(String(item_id)):
		return false
	discovered[String(item_id)] = true
	return true


func is_discovered(item_id: StringName) -> bool:
	return discovered.has(String(item_id))


func to_dict() -> Dictionary:
	var ids: Array = discovered.keys()
	ids.sort()
	return {"discovered": ids}


func from_dict(d: Dictionary) -> void:
	discovered.clear()
	for id in d.get("discovered", []):
		discovered[String(id)] = true
