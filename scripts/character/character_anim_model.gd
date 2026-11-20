## Which animation clip a character plays (spec 11.7). Pure: a player state plus what the
## state is doing (tool, emote, interaction, moving) maps to a clip of the merged Universal
## Animation Library. Returns {"clip", "then" (queued loop after a one-shot, or &""),
## "hold" (freeze on the first frame)}. Gameplay timing never waits on a clip.
class_name CharacterAnimModel
extends RefCounted

const IDLE := &"Idle"
const WALK := &"Walk"

const TOOL_CLIPS := {
	ToolTypes.PICKAXE: &"TreeChopping", ToolTypes.SHOVEL: &"TreeChopping", ToolTypes.AXE: &"TreeChopping",
	ToolTypes.HOE: &"Farm_PlantSeed", ToolTypes.WATERING_CAN: &"Farm_Watering", ToolTypes.FRUIT_PICKER: &"Farm_Harvest",
	ToolTypes.HAMMER: &"Fixing_Kneeling", ToolTypes.SCREWDRIVER: &"Fixing_Kneeling",
	ToolTypes.PAINTBRUSH: &"Interact", ToolTypes.STAMP: &"Interact",
}
const EMOTE_CLIPS := {
	&"emote_wave": &"Interact", &"emote_dance": &"Dance", &"emote_cheer": &"Yes", &"emote_clap": &"Idle_FoldArms",
	&"emote_heart": &"Idle_Talking", &"emote_sleepy": &"Idle_No", &"emote_laugh": &"Idle_Talking", &"emote_point": &"Interact",
}
const INTERACT_CLIPS := {&"STORAGE": &"Chest_Open", &"CHEST": &"Chest_Open", &"EAT": &"Consume", &"PICKUP": &"PickUp_Table"}
## NPC reactions to emotes (spec 7.4).
const REACTION_CLIPS := {
	&"wave": &"Interact", &"clap": &"Idle_FoldArms", &"cheer": &"Yes", &"smile": &"Yes", &"heart": &"Idle_Talking",
	&"yawn": &"Idle_No", &"laugh": &"Idle_Talking", &"look": &"Idle",
}


static func _r(clip: StringName, then: StringName = &"", hold: bool = false) -> Dictionary:
	return {"clip": clip, "then": then, "hold": hold}


## info keys (all optional): moving: bool, tool: StringName, emote: StringName,
## interact: StringName (InteractionSpec kind), working: bool (Build: hands busy).
static func for_player(state: StringName, info: Dictionary = {}) -> Dictionary:
	var moving: bool = info.get("moving", false)
	match state:
		PlayerTransitionTable.IDLE: return _r(IDLE)
		PlayerTransitionTable.WALK: return _r(WALK)
		PlayerTransitionTable.RUN: return _r(&"Jog_Fwd")
		PlayerTransitionTable.DUCK: return _r(&"Crouch_Fwd" if moving else &"Crouch_Idle")
		PlayerTransitionTable.JUMP: return _r(&"Jump_Start", &"Jump")
		PlayerTransitionTable.FALL: return _r(&"Jump")
		PlayerTransitionTable.MINE: return _r(TOOL_CLIPS.get(info.get("tool", &""), &"TreeChopping"))
		PlayerTransitionTable.INTERACT: return _r(INTERACT_CLIPS.get(info.get("interact", &""), &"Interact"))
		PlayerTransitionTable.SLEEP: return _r(&"LayToIdle", &"", true)
		PlayerTransitionTable.BUILD:
			if info.get("working", false):
				return _r(&"Fixing_Kneeling")
			return _r(WALK if moving else IDLE)
		PlayerTransitionTable.SIT: return _r(&"Sitting_Enter", &"Sitting_Idle")
		PlayerTransitionTable.CRAFT: return _r(&"Fixing_Kneeling")
		PlayerTransitionTable.TALK: return _r(&"Idle_Talking")
		PlayerTransitionTable.EMOTE: return _r(EMOTE_CLIPS.get(info.get("emote", &""), &"Yes"))
		PlayerTransitionTable.PLAY_INSTRUMENT: return _r(&"Idle_Lantern")
	return _r(IDLE)


static func for_npc(moving: bool, talking: bool, reaction: StringName) -> Dictionary:
	if reaction != &"":
		return _r(REACTION_CLIPS.get(reaction, IDLE))
	if talking:
		return _r(&"Idle_Talking")
	return _r(WALK if moving else IDLE)


## Every clip name this model can return (tests check they exist in the library).
static func all_clips() -> Array[StringName]:
	var out: Array[StringName] = [IDLE, WALK, &"Jog_Fwd", &"Crouch_Fwd", &"Crouch_Idle", &"Jump_Start", &"Jump",
		&"LayToIdle", &"Sitting_Enter", &"Sitting_Idle", &"Fixing_Kneeling", &"Idle_Talking", &"Idle_Lantern", &"Interact", &"TreeChopping"]
	for d in [TOOL_CLIPS, EMOTE_CLIPS, INTERACT_CLIPS, REACTION_CLIPS]:
		for v in d.values():
			if not (v in out):
				out.append(v)
	return out
