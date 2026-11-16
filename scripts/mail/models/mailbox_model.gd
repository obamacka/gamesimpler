## Mailbox (spec 3.3, Phase 2 core): monotonic ids, scheduled delivery, all-or-nothing claim.
class_name MailboxModel
extends RefCounted

var next_seq := 1
var inbox: Array = []       # message dictionaries, delivered
var scheduled: Array = []   # message dictionaries, not yet delivered


## Schedules a message from a template. Returns its id.
func schedule(tpl: MailTemplateDef, sent_day: int, deliver_day: int, params: Dictionary = {}) -> String:
	var id := "m_%06d" % next_seq
	next_seq += 1
	scheduled.append({
		"id": id, "template_id": String(tpl.id), "sender_id": String(tpl.sender_id), "kind": String(tpl.kind),
		"subject_key": tpl.subject_key, "body_key": tpl.body_key, "params": params.duplicate(true),
		"sent_day": sent_day, "deliver_day": deliver_day,
		"expires_day": 0 if tpl.expires_after_days == 0 else deliver_day + tpl.expires_after_days,
		"attachments": tpl.attachments.duplicate(true), "read": false, "claimed": false, "archived": false,
	})
	return id


## Moves every scheduled message with deliver_day <= day into the inbox (idempotent).
## Returns delivered ids in id order.
func deliver_due(day: int) -> Array[String]:
	var due: Array = scheduled.filter(func(m): return int(m["deliver_day"]) <= day)
	due.sort_custom(func(a, b): return a["id"] < b["id"])
	scheduled = scheduled.filter(func(m): return int(m["deliver_day"]) > day)
	var ids: Array[String] = []
	for m in due:
		inbox.append(m)
		ids.append(m["id"])
	return ids


func find(id: String) -> Dictionary:
	for m in inbox:
		if m["id"] == id:
			return m
	return {}


func unread_count() -> int:
	return inbox.filter(func(m): return not m["read"]).size()


func mark_read(id: String) -> void:
	var m := find(id)
	if not m.is_empty():
		m["read"] = true


## Claims every attachment or none. Fails with &"not_found", &"already_claimed", &"no_space".
func claim(id: String, inventory: InventoryModel, wallet: WalletModel) -> Result:
	var m := find(id)
	if m.is_empty():
		return Result.failure(&"not_found")
	if m["claimed"]:
		return Result.failure(&"already_claimed")
	var need := {}
	for a in m["attachments"]:
		if a.get("type", "") == "item":
			var item_id := StringName(a["item_id"])
			need[item_id] = int(need.get(item_id, 0)) + int(a.get("qty", 1))
	var probe := InventoryModel.new(inventory.slots.size(), inventory.max_stack_of)
	probe.from_dict(inventory.to_dict())
	for item_id in need:
		if probe.add(item_id, need[item_id]) > 0:
			return Result.failure(&"no_space")
	for item_id in need:
		inventory.add(item_id, need[item_id])
	for a in m["attachments"]:
		if a.get("type", "") == "coins":
			wallet.credit(int(a.get("amount", 0)))
	m["claimed"] = true
	m["read"] = true
	return Result.success(m["attachments"])


func to_dict() -> Dictionary:
	return {"next_mail_seq": next_seq, "inbox": inbox.duplicate(true), "scheduled": scheduled.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	next_seq = int(d.get("next_mail_seq", 1))
	inbox = _ints(d.get("inbox", []))
	scheduled = _ints(d.get("scheduled", []))


static func _ints(list: Array) -> Array:
	var out: Array = []
	for m in list:
		var c: Dictionary = m.duplicate(true)
		for k in ["sent_day", "deliver_day", "expires_day"]:
			c[k] = int(c.get(k, 0))
		for a in c.get("attachments", []):
			if a.has("qty"):
				a["qty"] = int(a["qty"])
			if a.has("amount"):
				a["amount"] = int(a["amount"])
		out.append(c)
	return out
