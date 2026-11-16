## Talk (spec 4.5): the NPC stops and faces the player, the camera frames both, then the
## dialogue menu opens (pauses). Closing it returns to Idle and the NPC resumes.
extends PlayerState

const BLEND := 0.3

var npc: Npc
var _t := 0.0
var _opened := false


func enter(_msg: Dictionary = {}) -> void:
	npc = player.pending_talk
	player.pending_talk = null
	player.context.talk_done = false
	if not is_instance_valid(npc):
		player.context.talk_done = true
		return
	npc.begin_talk(player)
	player.face_towards(npc.global_position)
	player.camera_rig.two_shot_target = npc
	player.session().npcs.talk(npc.npc_id)
	_t = 0.0
	_opened = false


## The camera blends to the two-shot for 0.3 s, then the dialogue opens (spec 4.5).
func physics_tick(delta: float, _f: InputFrame) -> void:
	if _opened or player.context.talk_done:
		return
	_t += delta
	if _t + 0.0001 < BLEND:
		return
	_opened = true
	if MenuStack.instance == null or MenuStack.instance.push(&"dialogue", {"npc_id": npc.npc_id,
			"on_close": func(_r): player.context.talk_done = true}) == null:
		player.context.talk_done = true


func exit() -> void:
	if is_instance_valid(npc):
		npc.end_talk()
	player.camera_rig.two_shot_target = null
	npc = null


func locks_tool() -> bool:
	return true
