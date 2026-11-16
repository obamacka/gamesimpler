## Emote (spec 4.5 thin state, 7.4): locks the 1.5 to 3 s animation so pet and NPC reactions
## play out. Moving ends it early.
extends PlayerState

var emote: EmoteDef
var _t := 0.0


func enter(_msg: Dictionary = {}) -> void:
	emote = Database.emotes.get(player.pending_emote)
	player.pending_emote = &""
	_t = 0.0
	player.context.emote_done = emote == null
	if emote:
		var s := player.session()
		EventBus.player_emoted.emit(emote.id, player.global_position)
		s.npcs.on_emote(emote.id, player.global_position, player.get_tree().get_nodes_in_group(&"npcs"))


func physics_tick(delta: float, _f: InputFrame) -> void:
	_t += delta
	if emote and _t >= emote.duration_sec:
		player.context.emote_done = true


func locks_tool() -> bool:
	return true
