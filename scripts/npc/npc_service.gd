## NPC friendship, gifts, waves and friendship letters (spec 1.8, 7.4, P5.2).
class_name NpcService
extends Node

var session: GameSession
var model := NpcModel.new()


func setup(s: GameSession) -> void:
	session = s


func talk(npc_id: StringName) -> int:
	var gain := model.talk(npc_id, session.day(), Database.friendship)
	_after_gain(npc_id, gain)
	return gain


func try_gift(npc_id: StringName, item_id: StringName) -> Result:
	var def: NpcDef = Database.npcs.get(npc_id)
	if def == null:
		return Result.failure(&"unknown")
	if session.inventory.count(item_id) <= 0:
		return Result.failure(&"no_item")
	var r := model.gift(def, Database.item(item_id), session.day(), Database.friendship)
	if not r["ok"]:
		return Result.failure(r["reason"])
	session.inventory.remove(item_id, 1)
	EventBus.npc_gifted.emit(npc_id, item_id, r["pref"], r["gain"])
	_after_gain(npc_id, r["gain"])
	return Result.success(r)


## Emote reactions (spec 7.4): NPCs within 6 m react; the first wave per NPC per day is +1.
func on_emote(emote_id: StringName, at: Vector3, npc_nodes: Array) -> Array:
	var reacted: Array = []
	var def: EmoteDef = Database.emotes.get(emote_id)
	for n in npc_nodes:
		if not is_instance_valid(n) or (n as Node3D).global_position.distance_to(at) > 6.0:
			continue
		n.react(def.npc_reaction if def else &"look")
		reacted.append(n.npc_id)
		if emote_id == &"emote_wave":
			_after_gain(n.npc_id, model.wave(n.npc_id, session.day(), Database.friendship))
	return reacted


func _after_gain(npc_id: StringName, gain: int) -> void:
	if gain <= 0:
		return
	EventBus.friendship_changed.emit(npc_id, int(model.of(npc_id)["friendship"]))
	var s := model.of(npc_id)
	for l in Database.friendship.get("letters", []):
		var flag := "letter_%d" % int(l["threshold"])
		if int(s["friendship"]) >= int(l["threshold"]) and not (flag in s["flags"]):
			s["flags"].append(flag)
			var tpl: MailTemplateDef = Database.mail_templates.get(l["template"])
			if tpl:
				session.mail.schedule(tpl, session.day() + 1, {"sender_id": String(npc_id)})


func best_friend() -> StringName:
	return model.best_friend()
