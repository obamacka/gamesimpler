## Mail service (spec 3.3, Phase 2 core).
class_name MailService
extends Node

var model := MailboxModel.new()
var session: GameSession


func setup(s: GameSession) -> void:
	session = s


func schedule(tpl: MailTemplateDef, deliver_day: int, params: Dictionary = {}) -> String:
	return model.schedule(tpl, session.day(), deliver_day, params)


func deliver_due(day: int) -> void:
	var ids := model.deliver_due(day)
	if not ids.is_empty():
		EventBus.mail_delivered.emit(ids)


func claim(id: String) -> Result:
	var r := model.claim(id, session.inventory.model, session.wallet.model)
	if r.ok:
		EventBus.inventory_changed.emit()
		EventBus.mail_claimed.emit(id)
	return r


## Temporary Phase 2 mailbox action: claims every unclaimed message (replaced by the mail menu in P5.13).
func claim_all() -> int:
	var n := 0
	for m in model.inbox:
		if not m["claimed"] and claim(m["id"]).ok:
			n += 1
	return n
