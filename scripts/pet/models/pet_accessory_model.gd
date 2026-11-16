## Pet accessories (spec 7.1). Pure: validates and swaps against an InventoryModel.
class_name PetAccessoryModel
extends RefCounted

const NOT_ACCESSORY := &"not_accessory"
const NO_MESH := &"no_mesh_for_species"
const NO_SPACE := &"no_space"
const EMPTY := &"empty"


static func can_equip(item_id: StringName, species: StringName) -> StringName:
	var a: PetAccessoryDef = Database.pet_accessories.get(item_id)
	if a == null:
		return NOT_ACCESSORY
	if not (species in a.species):
		return NO_MESH
	return &""


## Moves backpack slot `i` onto the pet; the previous accessory returns to the backpack.
func equip(pet: Dictionary, inv: InventoryModel, i: int) -> Dictionary:
	var st = inv.slots[i] if i >= 0 and i < inv.slots.size() else null
	if st == null:
		return {"ok": false, "reason": EMPTY}
	var reason := can_equip(st["item_id"], StringName(pet["species_id"]))
	if reason != &"":
		return {"ok": false, "reason": reason}
	var a: PetAccessoryDef = Database.pet_accessories[st["item_id"]]
	var taken := inv.take_slot(i, 1)
	var data: Dictionary = taken["data"]
	if not data.has("dye") and a.default_dye_id != &"":
		data["dye"] = String(a.default_dye_id)
	var old = pet["accessories"][String(a.slot)]
	pet["accessories"][String(a.slot)] = {"item_id": String(taken["item_id"]), "data": data}
	if old != null:
		inv.add(StringName(old["item_id"]), 1, old["data"])
	return {"ok": true, "reason": &"", "slot": a.slot}


func remove(pet: Dictionary, inv: InventoryModel, slot: StringName) -> Dictionary:
	var cur = pet["accessories"].get(String(slot))
	if cur == null:
		return {"ok": false, "reason": EMPTY}
	if not inv.can_add(StringName(cur["item_id"]), 1, cur["data"]):
		return {"ok": false, "reason": NO_SPACE}
	inv.add(StringName(cur["item_id"]), 1, cur["data"])
	pet["accessories"][String(slot)] = null
	return {"ok": true, "reason": &""}


static func color_of(stack: Dictionary) -> Color:
	var dye: DyeDef = Database.dyes.get(StringName(stack["data"].get("dye", "")))
	if dye:
		return dye.color
	var a: PetAccessoryDef = Database.pet_accessories.get(StringName(stack["item_id"]))
	return a.color if a else Color.WHITE
