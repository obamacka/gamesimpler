## Outfit equipment (spec 3.4, P4.8). Worn pieces leave the backpack; swapping returns the
## previous piece. Dyes must be unlocked (D12).
class_name OutfitService
extends Node

var session: GameSession
var model := OutfitModel.new()


func setup(s: GameSession) -> void:
	session = s


func equip_from_slot(slot_index: int) -> Result:
	var inv := session.inventory.model
	var st = inv.slots[slot_index] if slot_index >= 0 and slot_index < inv.slots.size() else null
	if st == null or Database.item(st["item_id"]).category != &"OUTFIT":
		return Result.failure(&"not_outfit")
	var taken := inv.take_slot(slot_index, 1)
	var old = model.equip(taken["item_id"], taken["data"])
	if old != null:
		inv.add(old["item_id"], 1, old["data"])
	var slot := OutfitModel.outfit_of(taken["item_id"]).slot
	EventBus.outfit_changed.emit(slot)
	EventBus.inventory_changed.emit()
	return Result.success(slot)


func unequip(slot: StringName) -> Result:
	var s = model.slots.get(slot)
	if s == null:
		return Result.failure(&"empty")
	if not session.inventory.model.can_add(s["item_id"], 1, s["data"]):
		return Result.failure(&"no_space")
	model.unequip(slot)
	session.inventory.model.add(s["item_id"], 1, s["data"])
	EventBus.outfit_changed.emit(slot)
	EventBus.inventory_changed.emit()
	return Result.success()


func set_dye(slot: StringName, dye_id: StringName) -> Result:
	if not session.unlocks.model.is_unlocked(&"DYE", dye_id):
		return Result.failure(&"locked")
	if not model.set_dye(slot, dye_id):
		return Result.failure(&"not_dyeable")
	EventBus.outfit_changed.emit(slot)
	return Result.success()


## Snapshot for the customizer's cancel (spec 8 P4.22).
func snapshot() -> Dictionary:
	return {"outfit": model.to_dict(), "inv": session.inventory.model.to_dict()}


func restore(snap: Dictionary) -> void:
	model.from_dict(snap["outfit"])
	session.inventory.model.from_dict(snap["inv"])
	for slot in OutfitDef.SLOTS:
		EventBus.outfit_changed.emit(slot)
	EventBus.inventory_changed.emit()
