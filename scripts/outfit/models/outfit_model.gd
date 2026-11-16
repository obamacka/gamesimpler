## Worn outfit (spec 3.4, plan P4.8). Pure. Slots hold {"item_id", "data": {"dye"}} or null.
class_name OutfitModel
extends RefCounted

var slots: Dictionary = {&"HEAD": null, &"TOP": null, &"BOTTOM": null, &"FEET": null, &"ACCESSORY": null}


## Puts `item_id` in its outfit slot. Returns the previous stack (or null).
func equip(item_id: StringName, data: Dictionary = {}) -> Variant:
	var def := outfit_of(item_id)
	if def == null:
		return null
	var old = slots[def.slot]
	var d := data.duplicate(true)
	if not d.has("dye") and def.default_dye_id != &"":
		d["dye"] = String(def.default_dye_id)
	slots[def.slot] = {"item_id": item_id, "data": d}
	return old


func unequip(slot: StringName) -> Variant:
	var old = slots.get(slot)
	slots[slot] = null
	return old


func set_dye(slot: StringName, dye_id: StringName) -> bool:
	var s = slots.get(slot)
	if s == null or not Database.dyes.has(dye_id):
		return false
	var def := outfit_of(s["item_id"])
	if def == null or not def.dyeable:
		return false
	s["data"]["dye"] = String(dye_id)
	return true


static func outfit_of(item_id: StringName) -> OutfitDef:
	var it := Database.item(item_id)
	return Database.outfits.get(it.outfit_id) if it else null


## Union of hide_body_regions of every worn piece (sorted, unique).
func hidden_regions() -> Array[StringName]:
	var out: Array[StringName] = []
	for slot in slots:
		var s = slots[slot]
		if s == null:
			continue
		for r in outfit_of(s["item_id"]).hide_body_regions:
			if not (r in out):
				out.append(r)
	out.sort_custom(func(a, b): return String(a) < String(b))   # StringName sort is not alphabetical
	return out


func color_of(slot: StringName) -> Color:
	var s = slots.get(slot)
	if s == null:
		return Color.TRANSPARENT
	var dye: DyeDef = Database.dyes.get(StringName(s["data"].get("dye", "")))
	return dye.color if dye else outfit_of(s["item_id"]).color


func to_dict() -> Dictionary:
	var out := {}
	for slot in slots:
		var s = slots[slot]
		out[String(slot)] = null if s == null else {"item_id": String(s["item_id"]), "data": s["data"].duplicate(true)}
	return out


func from_dict(d: Dictionary) -> void:
	for slot in slots:
		var s = d.get(String(slot))
		slots[slot] = null if s == null or not Database.items.has(StringName(s["item_id"])) else {"item_id": StringName(s["item_id"]), "data": (s.get("data", {}) as Dictionary).duplicate(true)}
