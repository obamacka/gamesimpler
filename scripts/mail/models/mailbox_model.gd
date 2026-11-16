## Mailbox (spec 3.3, Phase 2 core): monotonic ids, scheduled delivery, all-or-nothing claim.
class_name MailboxModel
extends RefCounted

const INBOX_CAP := 60
const NEVER_EXPIRE := ["CARE_PACKAGE", "RECEIPT", "REWARD", "PACKAGE", "CATALOG_ORDER"]
const ITEM_TYPES := ["item"]

var next_seq := 1
var inbox: Array = []       # message dictionaries, delivered
var scheduled: Array = []   # message dictionaries, not yet delivered
var lost_and_found: Array = []   # attachments of expired unclaimed messages (never lost)


## Schedules a message from a template. Returns its id.
func schedule(tpl: MailTemplateDef, sent_day: int, deliver_day: int, params: Dictionary = {}) -> String:
	var id := "m_%06d" % next_seq
	next_seq += 1
	scheduled.append({
		"id": id, "template_id": String(tpl.id), "sender_id": String(params.get("sender_id", tpl.sender_id)), "kind": String(tpl.kind),
		"subject_key": tpl.subject_key, "body_key": tpl.body_key, "params": _without(params, "attachments"),
		"sent_day": sent_day, "deliver_day": deliver_day,
		"expires_day": 0 if tpl.expires_after_days == 0 or String(tpl.kind) in NEVER_EXPIRE else deliver_day + tpl.expires_after_days,
		"attachments": (params["attachments"] if params.has("attachments") else tpl.attachments).duplicate(true),
		"read": false, "claimed": false, "archived": false,
	})
	scheduled[-1] = _ints([scheduled[-1]])[0]
	return id


static func _without(d: Dictionary, key: String) -> Dictionary:
	var c := d.duplicate(true)
	c.erase(key)
	return c


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


## Expiry (spec 3.3): unclaimed messages past expires_day move their attachments to Lost and
## Found and are archived. Then the inbox is pruned to INBOX_CAP, removing only messages that
## are both archived and claimed (oldest first). Returns expired ids.
func expire_and_prune(day: int) -> Array:
	var expired: Array = []
	for m in inbox:
		if int(m["expires_day"]) > 0 and day > int(m["expires_day"]) and not m["claimed"] and not m["archived"]:
			for a in m["attachments"]:
				lost_and_found.append(a.duplicate(true))
			m["attachments"] = []
			m["archived"] = true
			m["claimed"] = true
			expired.append(m["id"])
	prune()
	return expired


## Removes the oldest messages that are both archived and claimed until the inbox fits.
func prune() -> void:
	var removable := inbox.filter(func(m): return m["archived"] and m["claimed"])
	while inbox.size() > INBOX_CAP and not removable.is_empty():
		inbox.erase(removable.pop_front())


func archive(id: String) -> bool:
	var m := find(id)
	if m.is_empty():
		return false
	m["archived"] = true
	m["read"] = true
	return true


## Claims every attachment or none. Fails with &"not_found", &"already_claimed", &"no_space".
## Non-item attachments are returned in data for the MailService to apply (unlocks, contract,
## pet adoption); items and coins are applied here.
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
	return {"next_mail_seq": next_seq, "inbox": inbox.duplicate(true), "scheduled": scheduled.duplicate(true), "lost_and_found": lost_and_found.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	next_seq = int(d.get("next_mail_seq", 1))
	inbox = _ints(d.get("inbox", []))
	scheduled = _ints(d.get("scheduled", []))
	lost_and_found = _ints([{"attachments": d.get("lost_and_found", [])}])[0]["attachments"]


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
