## Dye palette (spec 7.2): unlocked dyes by name and swatch. result: the dye id.
extends MenuBase


func build() -> void:
	make_list("Dyes", Vector2(480, 420))
	var s := GameSession.current
	for id in Database.dyes:
		if s.unlocks.model.is_unlocked(&"DYE", id):
			var d: StringName = id
			add_row(Database.dyes[id].name_key, Database.dyes[id].color, func(): close(d))


func initial_focus() -> Control:
	return first_enabled()
