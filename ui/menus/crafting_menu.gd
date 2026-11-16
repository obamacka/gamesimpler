## Crafting (spec 5.8, D4): recipes for this station plus HAND recipes. Instant recipes craft
## here; timed ones close the menu and hand off to the Craft state. args: {"station"}.
## result: {"handoff": &"craft", "recipe": StringName} for timed recipes.
extends MenuBase

const REASONS := {&"missing_inputs": "Missing materials", &"not_enough_coins": "Not enough coins",
	&"no_space": "Backpack is full", &"locked": "Not learned yet"}

var station: StringName


func build() -> void:
	station = StringName(args.get("station", "HAND"))
	make_list("Crafting", Vector2(720, 500))
	refresh()


func recipes() -> Array:
	return Database.recipes.values().filter(func(r): return r.station == station or r.station == &"HAND")


func refresh() -> void:
	var s := GameSession.current
	clear_rows()
	for r in recipes():
		var c := s.economy.tx.craft_check(r.id, station)
		var miss := ", ".join(c["missing"].map(func(m): return "%s %d/%d" % [MenuBase.item_name(m["item"]), m["have"], m["need"]]))
		var text := "%s%s" % [MenuBase.item_name(r.outputs[0]["item"]), "" if miss == "" else "  (need %s)" % miss]
		if c["reason"] == CraftModel.LOCKED:
			text = "??? (not learned yet)"
		var rid: StringName = r.id
		add_row(text, MenuBase.item_color(r.outputs[0]["item"]), func(): choose(rid), c["reason"] != CraftModel.LOCKED)


func initial_focus() -> Control:
	return first_enabled()


func choose(recipe_id: StringName) -> Result:
	var s := GameSession.current
	var c := s.economy.tx.craft_check(recipe_id, station)
	if c["reason"] != CraftModel.OK:
		say(REASONS.get(c["reason"], String(c["reason"])))
		return Result.failure(c["reason"])
	var r: RecipeDef = Database.recipes[recipe_id]
	if r.craft_time_sec <= 0.0:
		var res := s.economy.tx.try_craft(recipe_id, station)
		say("Made it!" if res.ok else String(res.error))
		refresh()
		return res
	close({"handoff": &"craft", "recipe": recipe_id, "station": station})
	return Result.success(&"handoff")
