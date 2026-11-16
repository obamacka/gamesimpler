## Mail service (spec 3.3, Phase 2 core).
class_name MailService
extends Node

var model := MailboxModel.new()
var session: GameSession


func setup(s: GameSession) -> void:
	session = s


func schedule(tpl: MailTemplateDef, deliver_day: int, params: Dictionary = {}) -> String:
	return model.schedule(tpl, session.day(), deliver_day, params)


const UNLOCK_KINDS := {"unlock_recipe": &"BLUEPRINT", "unlock_dye": &"DYE", "unlock_sticker": &"STICKER",
	"unlock_emote": &"EMOTE", "unlock_instrument": &"INSTRUMENT"}


## Rollover step `mail_deliver`: expire, prune, then deliver (spec 3.3).
func deliver_due(day: int) -> void:
	model.expire_and_prune(day)
	var ids := model.deliver_due(day)
	model.prune()
	if not ids.is_empty():
		EventBus.mail_delivered.emit(ids)


func read(id: String) -> void:
	var m := model.find(id)
	if not m.is_empty() and not m["read"]:
		model.mark_read(id)
		EventBus.mail_read.emit(id)


## All-or-nothing claim (spec 3.3). Items and coins land in the model; unlocks, contracts
## and the pet adoption ticket are applied here after the item check passed.
func claim(id: String) -> Result:
	var m := model.find(id)
	if not m.is_empty() and not m["claimed"]:
		for a in m["attachments"]:
			if a.get("type", "") == "contract" and not session.jobs.find_active(StringName(a.get("contract_id", ""))).is_empty():
				return Result.failure(&"contract_already_active")
	var r := model.claim(id, session.inventory.model, session.wallet.model)
	if not r.ok:
		return r
	for a in r.data:
		var t: String = a.get("type", "")
		if UNLOCK_KINDS.has(t):
			session.unlocks.grant(UNLOCK_KINDS[t], StringName(a.get("id", "")))
		elif t == "contract":
			session.jobs.accept_contract(StringName(a.get("contract_id", "")))
		elif t == "pet_adoption":
			EventBus.pet_adoption_claimed.emit()
		elif t == "coins":
			EventBus.coins_changed.emit(session.wallet.model.coins - int(a.get("amount", 0)), session.wallet.model.coins)
	EventBus.inventory_changed.emit()
	EventBus.mail_claimed.emit(id)
	return r


func archive(id: String) -> bool:
	return model.archive(id)


## Lost and Found (spec 3.3): expired attachments, claimable all-or-nothing.
func claim_lost_and_found() -> Result:
	if model.lost_and_found.is_empty():
		return Result.failure(&"empty")
	var need := {}
	for a in model.lost_and_found:
		if a.get("type", "") == "item":
			need[StringName(a["item_id"])] = int(need.get(StringName(a["item_id"]), 0)) + int(a.get("qty", 1))
	var probe := InventoryModel.new(session.inventory.model.slots.size(), session.inventory.model.max_stack_of)
	probe.from_dict(session.inventory.model.to_dict())
	for k in need:
		if probe.add(k, need[k]) > 0:
			return Result.failure(&"no_space")
	for a in model.lost_and_found:
		match a.get("type", ""):
			"item": session.inventory.model.add(StringName(a["item_id"]), int(a.get("qty", 1)))
			"coins": session.wallet.model.credit(int(a.get("amount", 0)))
			_:
				if UNLOCK_KINDS.has(a.get("type", "")):
					session.unlocks.grant(UNLOCK_KINDS[a["type"]], StringName(a.get("id", "")))
	model.lost_and_found.clear()
	EventBus.inventory_changed.emit()
	return Result.success()


## Catalog order (spec P5.4): pay now through the coordinator rules, delivered next day.
func order(shop_id: StringName, item_id: StringName, qty: int) -> Result:
	var tx := session.economy.tx
	var shop: ShopDef = Database.shops.get(shop_id)
	if shop == null or not shop.sells(item_id) or qty <= 0:
		return Result.failure(&"not_sold_here")
	var left := session.economy.remaining(shop_id, item_id)
	if left >= 0 and left < qty:
		return Result.failure(&"out_of_stock")
	var total := tx.buy_quote(shop_id, item_id, qty)
	if not session.wallet.debit(total):
		return Result.failure(&"not_enough_coins")
	session.economy.take_stock(shop_id, item_id, qty)
	var tpl: MailTemplateDef = Database.mail_templates[&"mail_tpl_catalog_order"]
	var id := schedule(tpl, session.day() + 1, {"attachments": [{"type": "item", "item_id": String(item_id), "qty": qty}]})
	return Result.success(id)
