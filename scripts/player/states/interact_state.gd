## Context-aware Interact (spec 4.5): Approach (turn) -> Perform (anim time) -> Resolve or Handoff.
extends PlayerState

const TURN_TIME := 0.3

var target: Node3D   # Interactable or FarmActionTarget (both offer spec_for / resolve)
var spec: InteractionSpec
var _t := 0.0
var _menu_state := 0   # 0 none, 1 open, 2 closed with result


func enter(msg: Dictionary = {}) -> void:
	player.context.interact_done = false
	player.context.interact_handoff = &""
	_t = 0.0
	_menu_state = 0
	target = player.farm_target if msg.get("effect", &"") == PlayerTransitionTable.FX_FARM else player.focused_interactable()
	if target == null:
		player.context.interact_done = true
		return
	spec = target.spec_for(player, msg.get("effect", &"") == PlayerTransitionTable.FX_FORAGE, player.last_frame_alt())
	if spec == null:
		player.context.interact_done = true


func physics_tick(delta: float, f: InputFrame) -> void:
	if player.context.interact_done:
		return
	_t += delta
	player.face_towards(target.global_position)
	if _t < TURN_TIME + spec.duration_sec:
		return
	# OpenMenu step (spec 4.5): the menu pauses the game; resolve after it closes.
	if spec.opens_menu != &"" and _menu_state == 0:
		if MenuStack.instance:
			_menu_state = 1
			var args := spec.menu_args.duplicate()
			args["on_close"] = func(res): spec.menu_result = res; _menu_state = 2
			if MenuStack.instance.push(spec.opens_menu, args) == null:
				_menu_state = 2
			return
		push_warning("Interact: no MenuStack for %s; accepting the default" % spec.opens_menu)
		spec.menu_result = &"yes"
		_menu_state = 2
	if _menu_state == 1:
		return
	if spec.stamina_cost > 0:
		player.session().stamina.spend(spec.stamina_cost, spec.kind)
	target.resolve(spec, player)
	# Watering repeats while RT stays held and the aim moves to another dry cell (plan P2B.7).
	if spec.kind == &"WATER" and f.use_held and not player.context.exhaustion_pending \
			and player.refresh_farm_target().get("action", &"") == &"water":
		_t = TURN_TIME
		return
	player.context.interact_handoff = spec.handoff_state
	player.context.interact_done = true


func locks_tool() -> bool:
	return true
