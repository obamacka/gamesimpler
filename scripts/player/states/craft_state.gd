## Craft (spec 4.2, D4): timed crafting in the world. Moving or ducking cancels and nothing
## is consumed; when the timer ends the coordinator commits try_craft.
extends PlayerState

var recipe: StringName
var station: StringName
var _t := 0.0
var _need := 0.0


func enter(_msg: Dictionary = {}) -> void:
	var p: Dictionary = player.pending_craft
	recipe = p.get("recipe", &"")
	station = p.get("station", &"")
	player.pending_craft = {}
	_t = 0.0
	var r: RecipeDef = Database.recipes.get(recipe)
	_need = r.craft_time_sec if r else 0.0
	player.context.craft_done = r == null
	if r:
		EventBus.craft_started.emit(recipe, _need)


func physics_tick(delta: float, _f: InputFrame) -> void:
	if player.context.craft_done:
		return
	_t += delta
	if _t + 0.000001 >= _need:
		player.session().economy.tx.try_craft(recipe, station)
		player.context.craft_done = true


func exit() -> void:
	if not player.context.craft_done and recipe != &"":
		EventBus.craft_cancelled.emit(recipe)
	player.context.craft_done = false


func locks_tool() -> bool:
	return true


func progress() -> float:
	return clampf(_t / _need, 0.0, 1.0) if _need > 0.0 else 1.0
