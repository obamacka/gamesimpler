## Storage containers (spec 7.3 STORAGE): one InventoryModel per chest piece uid.
class_name StorageService
extends Node

var session: GameSession
var containers: Dictionary = {}   # uid -> InventoryModel


func setup(s: GameSession) -> void:
	session = s


func container(uid: String) -> InventoryModel:
	if not containers.has(uid):
		var slots := 12
		var def := session.build.def_of(uid)
		if def:
			slots = maxi(1, int(def.interaction(&"STORAGE").get("slots", 12)))
		containers[uid] = InventoryModel.new(slots)
	return containers[uid]


func has_items(uid: String) -> bool:
	return containers.has(uid) and containers[uid].slots.any(func(s): return s != null)


## Backpack slot -> container (or back with to_backpack). All-or-nothing per move.
func store(uid: String, backpack_slot: int, qty: int) -> Result:
	if not session.inventory.model.transfer_to(container(uid), backpack_slot, qty):
		return Result.failure(&"no_space")
	EventBus.inventory_changed.emit()
	return Result.success()


func take(uid: String, container_slot: int, qty: int) -> Result:
	if not container(uid).transfer_to(session.inventory.model, container_slot, qty):
		return Result.failure(&"no_space")
	EventBus.inventory_changed.emit()
	return Result.success()


func to_dict() -> Dictionary:
	var out := {}
	for uid in containers:
		out[uid] = containers[uid].to_dict()["backpack"]
	return out


func from_dict(d: Dictionary) -> void:
	containers.clear()
	for uid in d:
		var inv := InventoryModel.new(maxi(1, (d[uid] as Array).size()))
		inv.from_dict({"backpack": d[uid]})
		containers[String(uid)] = inv
