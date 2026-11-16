## Context-aware Interact (spec 4.5): Approach (turn) -> Perform (anim time) -> Resolve or Handoff.
extends PlayerState

const TURN_TIME := 0.3

var target: Interactable
var spec: InteractionSpec
var _t := 0.0


func enter(msg: Dictionary = {}) -> void:
	player.context.interact_done = false
	player.context.interact_handoff = &""
	_t = 0.0
	target = player.focused_interactable()
	if target == null:
		player.context.interact_done = true
		return
	spec = target.spec_for(player, msg.get("effect", &"") == PlayerTransitionTable.FX_FORAGE, player.last_frame_alt())
	if spec == null:
		player.context.interact_done = true


func physics_tick(delta: float, _f: InputFrame) -> void:
	if player.context.interact_done:
		return
	_t += delta
	player.face_towards(target.global_position)
	if _t < TURN_TIME + spec.duration_sec:
		return
	if spec.stamina_cost > 0:
		player.session().stamina.spend(spec.stamina_cost, spec.kind)
	target.resolve(spec, player)
	player.context.interact_handoff = spec.handoff_state
	player.context.interact_done = true


func locks_tool() -> bool:
	return true
