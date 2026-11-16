## Slot inventory (spec 1.7, 3.1). Stacks: {"item_id": StringName, "qty": int, "data": Dictionary}.
## Stacks with non-empty data never merge. `max_stack_of` defaults to Database.max_stack.
class_name InventoryModel
extends RefCounted

var slots: Array = []   # Dictionary or null
var max_stack_of: Callable


func _init(slot_count: int = 24, stack_provider: Callable = Callable()) -> void:
	slots.resize(slot_count)
	max_stack_of = stack_provider if stack_provider.is_valid() else func(id): return Database.max_stack(id)


func count(item_id: StringName) -> int:
	var n := 0
	for s in slots:
		if s and s["item_id"] == item_id:
			n += int(s["qty"])
	return n


## How many of `qty` would fit right now.
func space_for(item_id: StringName, qty: int, data: Dictionary = {}) -> int:
	var max_stack: int = max_stack_of.call(item_id)
	var room := 0
	for s in slots:
		if s == null:
			room += max_stack if data.is_empty() else 1
		elif data.is_empty() and s["item_id"] == item_id and (s["data"] as Dictionary).is_empty():
			room += max_stack - int(s["qty"])
		if room >= qty:
			return qty
	return room


func can_add(item_id: StringName, qty: int, data: Dictionary = {}) -> bool:
	return space_for(item_id, qty, data) >= qty


## Adds as much as fits. Returns the overflow that did not fit (0 = all added).
func add(item_id: StringName, qty: int, data: Dictionary = {}) -> int:
	var max_stack: int = max_stack_of.call(item_id)
	var left := qty
	if data.is_empty():
		for s in slots:
			if left == 0:
				break
			if s and s["item_id"] == item_id and (s["data"] as Dictionary).is_empty() and int(s["qty"]) < max_stack:
				var put := mini(left, max_stack - int(s["qty"]))
				s["qty"] = int(s["qty"]) + put
				left -= put
	for i in slots.size():
		if left == 0:
			break
		if slots[i] == null:
			var put := mini(left, max_stack if data.is_empty() else 1)
			slots[i] = {"item_id": item_id, "qty": put, "data": data.duplicate(true)}
			left -= put
	return left


## Removes exactly `qty` or nothing. Plain stacks (no instance data) are used first.
func remove(item_id: StringName, qty: int) -> bool:
	if count(item_id) < qty:
		return false
	var left := qty
	for pass_plain in [true, false]:
		for i in range(slots.size() - 1, -1, -1):
			if left == 0:
				break
			var s = slots[i]
			if s == null or s["item_id"] != item_id or (s["data"] as Dictionary).is_empty() != pass_plain:
				continue
			var take := mini(left, int(s["qty"]))
			s["qty"] = int(s["qty"]) - take
			left -= take
			if int(s["qty"]) == 0:
				slots[i] = null
	return true


func to_dict() -> Dictionary:
	var out: Array = []
	for s in slots:
		if s == null:
			out.append(null)
		else:
			var d := {"item_id": String(s["item_id"]), "qty": int(s["qty"])}
			if not (s["data"] as Dictionary).is_empty():
				d["data"] = s["data"].duplicate(true)
			out.append(d)
	return {"backpack": out}


func from_dict(d: Dictionary) -> void:
	var src: Array = d.get("backpack", [])
	for i in slots.size():
		var s = src[i] if i < src.size() else null
		slots[i] = null if s == null else {"item_id": StringName(s["item_id"]), "qty": int(s["qty"]), "data": (s.get("data", {}) as Dictionary).duplicate(true)}
