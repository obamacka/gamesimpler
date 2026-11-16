## Sticker sheet (spec 7.2): unlocked stickers and a size (S, M, L).
## result: {"id": StringName, "size": "S"|"M"|"L"}.
extends MenuBase

var sticker_size := "M"


func build() -> void:
	make_list("Stickers", Vector2(480, 460))
	refresh()


func refresh() -> void:
	clear_rows()
	for sz in ["S", "M", "L"]:
		var z: String = sz
		add_row(("> " if z == sticker_size else "") + "Size " + z, Color(0.8, 0.8, 0.8), func(): sticker_size = z; refresh())
	var s := GameSession.current
	for id in Database.stickers:
		if s.unlocks.model.is_unlocked(&"STICKER", id):
			var st: StringName = id
			add_row(Database.stickers[id].name_key, Database.stickers[id].color, func(): close({"id": st, "size": sticker_size}))


func initial_focus() -> Control:
	return first_enabled()
