## Chest reveal (spec 5.8, 6.4): a card with what the chest held. args: {"reward"}.
extends MenuBase

var cont: Button


func build() -> void:
	var r: Dictionary = args.get("reward", {})
	make_list("Treasure!", Vector2(460, 260))
	var l := Label.new()
	match r.get("kind", &""):
		&"COINS": l.text = "%d coins" % int(r.get("coins", 0))
		&"ITEM": l.text = "%s x%d" % [MenuBase.item_name(r.get("item", &"")), int(r.get("qty", 1))]
		&"DYE": l.text = "New dye: %s" % Database.dyes[r["id"]].name_key if Database.dyes.has(r.get("id", &"")) else "New dye"
		&"STICKER": l.text = "New sticker: %s" % Database.stickers[r["id"]].name_key if Database.stickers.has(r.get("id", &"")) else "New sticker"
		&"BLUEPRINT": l.text = "New blueprint: %s" % String(r.get("id", "")).trim_prefix("recipe_").replace("_", " ")
		_: l.text = "A surprise!"
	list.add_child(l)
	say(l.text)
	cont = add_row("Continue", Color(0.5, 0.8, 0.5), func(): close())


func initial_focus() -> Control:
	return cont
