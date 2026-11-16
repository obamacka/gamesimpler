## Museum donations, cases, trophies and rewards (spec 6.5), and geode opening (spec 6.4).
## rewards_granted is the single guard against double rewards; loading never re-emits
## item_donated, and reconcile() unlocks newly satisfied content exactly once.
class_name MuseumService
extends Node

var session: GameSession
var model := MuseumModel.new()


func setup(s: GameSession) -> void:
	session = s


func try_donate(item_id: StringName) -> Result:
	var r := model.donate(item_id, session.inventory.model, session.day())
	if not r["ok"]:
		return Result.failure(r["reason"])
	session.collection.mark_discovered(item_id)
	EventBus.inventory_changed.emit()
	EventBus.item_donated.emit(item_id, r["category"])
	_announce(r["cases"], r["trophies"])
	return Result.success(r)


## Dedupes first; each donation is independent (spec 6.5). Returns [{"item_id", "ok", "error"}].
func try_donate_batch(ids: Array) -> Array:
	var seen := {}
	var out: Array = []
	for id in ids:
		if seen.has(id):
			continue
		seen[id] = true
		var r := try_donate(StringName(id))
		out.append({"item_id": StringName(id), "ok": r.ok, "error": r.error})
	return out


func _announce(cases: Array, trophies: Array) -> void:
	for c in cases:
		EventBus.display_case_unlocked.emit(c)
	for t in trophies:
		EventBus.trophy_unlocked.emit(t)
	_grant_pending()


func _grant_pending() -> void:
	for tid in model.pending_rewards():
		var t: Dictionary = {}
		for x in Database.museum.trophies:
			if String(x["id"]) == tid:
				t = x
		if t.is_empty():
			continue
		model.rewards_granted.append(tid)
		var rw: Dictionary = t["reward"]
		session.stamina.model.bonus += int(rw["max_stamina_bonus"])   # applied now, capped by max_bonus_cap
		var att: Array = []
		if int(rw["coins"]) > 0:
			att.append({"type": "coins", "amount": int(rw["coins"])})
		for u in rw["unlocks"]:
			var kind: String = {&"DYE": "unlock_dye", &"STICKER": "unlock_sticker", &"BLUEPRINT": "unlock_recipe", &"EMOTE": "unlock_emote", &"INSTRUMENT": "unlock_instrument"}[u["kind"]]
			att.append({"type": kind, "id": String(u["id"])})
		var tpl: MailTemplateDef = Database.mail_templates.get(Database.museum.reward_mail)
		if tpl:
			session.mail.schedule(tpl, session.day() + 1, {"trophy_id": tid, "attachments": att})


## After loading (spec 6.5): newly satisfied cases and trophies unlock and reward once;
## recorded ones stay silent.
func reconcile() -> void:
	var newly := model.evaluate()
	_announce(newly["cases"], newly["trophies"])


## Geode opening in the donation menu: free, refused with "make room" if the backpack is full
## (the geode is then kept).
func open_geode(geode_item: StringName = &"item_geode") -> Result:
	if session.inventory.count(geode_item) <= 0:
		return Result.failure(&"no_geode")
	var result := GeodeModel.open(geode_item, session.collection.model, session.rng)
	if result == &"":
		return Result.failure(&"empty_geode")
	var probe := InventoryModel.new(session.inventory.model.slots.size(), session.inventory.model.max_stack_of)
	probe.from_dict(session.inventory.model.to_dict())
	probe.remove(geode_item, 1)
	if probe.add(result, 1) > 0:
		return Result.failure(&"no_space")
	session.inventory.remove(geode_item, 1)
	session.inventory.add(result, 1)
	EventBus.geode_opened.emit(geode_item, result)
	return Result.success(result)
