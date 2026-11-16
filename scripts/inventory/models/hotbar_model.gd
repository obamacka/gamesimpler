## Hotbar (spec 2.2): 8 references into the backpack and the selected index. Phase 2B needs
## the selection for the seed rule (spec 10.4); Phase 4 adds the UI to reassign references.
class_name HotbarModel
extends RefCounted

const SIZE := 8

var refs: Array = [0, 1, 2, 3, 4, 5, 6, 7]   # backpack slot index or null
var selected := 0


func select(i: int) -> void:
	selected = clampi(i, 0, SIZE - 1)


func next() -> void:
	selected = (selected + 1) % SIZE


func prev() -> void:
	selected = (selected + SIZE - 1) % SIZE


func selected_stack(inv: InventoryModel) -> Variant:
	var r = refs[selected]
	if r == null or int(r) >= inv.slots.size():
		return null
	return inv.slots[int(r)]


func selected_item_id(inv: InventoryModel) -> StringName:
	var s = selected_stack(inv)
	return s["item_id"] if s else &""


func to_dict() -> Dictionary:
	return {"hotbar_refs": refs.duplicate(), "hotbar_index": selected}


func from_dict(d: Dictionary) -> void:
	var r: Array = d.get("hotbar_refs", refs)
	refs = r.map(func(v): return null if v == null else int(v))
	selected = int(d.get("hotbar_index", 0))
