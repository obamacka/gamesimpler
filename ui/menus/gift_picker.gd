## Gift picker (spec 5.8): giftable items with heart icons for known preferences.
## args: {"npc_id"}. One gift per NPC per day.
extends MenuBase

const PREF_TEXT := {&"loved": "Loved it!", &"liked": "Liked it.", &"neutral": "Thank you.", &"disliked": "Oh... thanks."}

var npc_id: StringName


func build() -> void:
	npc_id = StringName(args.get("npc_id", ""))
	make_list("Give a gift to %s" % Database.npcs[npc_id].name_key, Vector2(560, 440))
	refresh()


func refresh() -> void:
	clear_rows()
	var s := GameSession.current
	var seen := {}
	for st in s.inventory.model.slots:
		if st == null or seen.has(st["item_id"]):
			continue
		var it := Database.item(st["item_id"])
		if not it.giftable or it.category in [&"TOOL", &"KEY_ITEM"]:
			continue
		seen[it.id] = true
		var id: StringName = it.id
		add_row(MenuBase.item_name(id), MenuBase.item_color(id), func(): give(id), true, null, MenuBase.item_icon(id))


func initial_focus() -> Control:
	return first_enabled()


func give(item_id: StringName) -> Result:
	var r := GameSession.current.npcs.try_gift(npc_id, item_id)
	if r.ok:
		say(PREF_TEXT.get(r.data["pref"], "Thank you."))
		close(r.data)
	else:
		say("One gift a day is plenty!" if r.error == NpcModel.ALREADY_GIFTED else String(r.error))
	return r
