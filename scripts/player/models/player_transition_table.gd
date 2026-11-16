## Pure transition rules for the player FSM (spec 4.2). Phase 1 covers locomotion and
## airborne rows; later phases add action rows (Mine, Interact, Build, ...).
## next() returns a Transition; `to == &""` means stay in the current state.
class_name PlayerTransitionTable
extends RefCounted

const IDLE := &"idle"
const WALK := &"walk"
const RUN := &"run"
const DUCK := &"duck"
const JUMP := &"jump"
const FALL := &"fall"
const SLEEP := &"sleep"
const MINE := &"mine"
const INTERACT := &"interact"

const MOVE_THRESHOLD := 0.2
const SOFT_LAND_HEIGHT := 4.0

# Effects carried to the entered state (or applied while staying).
const FX_NONE := &""
const FX_GROUND_JUMP := &"ground_jump"
const FX_AIR_JUMP := &"air_jump"
const FX_STAND_UP := &"stand_up"
const FX_BUMP := &"bump"
const FX_LOW_CEILING := &"low_ceiling"
const FX_CEILING := &"ceiling"
const FX_LAND := &"land"
const FX_SOFT_LAND := &"soft_land"
const FX_BUFFER := &"buffer"
const FX_FORAGE := &"forage"
const FX_BLOCKED := &"blocked"
const FX_TIER_LOW := &"tier_low"
const FX_AIR_STRIKE := &"air_strike"
const FX_FARM := &"farm"

const TARGET_VOXEL := &"voxel"
const TARGET_TIMBER := &"timber"
const TARGET_FRUIT_TREE := &"fruit_tree"
const TARGET_FARM := &"farm"

const GROUNDED: Array[StringName] = [IDLE, WALK, RUN, DUCK]
const AIRBORNE: Array[StringName] = [JUMP, FALL]


class Transition:
	var to: StringName
	var effect: StringName

	func _init(target: StringName = &"", fx: StringName = &"") -> void:
		to = target
		effect = fx

	func stays() -> bool:
		return to == &""


static func next(state: StringName, f: InputFrame, c: PlayerContext) -> Transition:
	if state in GROUNDED:
		return _grounded(state, f, c)
	if state == JUMP:
		return _jump(f, c)
	if state == FALL:
		return _fall(f, c)
	if state == MINE:
		return _mine(c)
	if state == INTERACT:
		return _interact(c)
	return Transition.new()


static func _moving_state(c: PlayerContext) -> StringName:
	return WALK if c.move_len > MOVE_THRESHOLD else IDLE


static func _grounded(state: StringName, f: InputFrame, c: PlayerContext) -> Transition:
	# Exhaustion pre-empts everything once the current step resolved (spec 4.1).
	if c.exhaustion_pending:
		return Transition.new(SLEEP)

	# Left the floor without jumping: stay grounded during coyote time, then fall.
	if not c.on_floor and c.coyote_left <= 0.0:
		return Transition.new(FALL)

	# Actions (spec 4.2 table order: interact, forage with the picker, mine). Run slows to Walk first.
	var wants_interact := (f.interact_pressed or f.interact_alt_pressed) and c.has_interact_target
	var wants_tool := f.use_pressed and c.tool_target_kind != &""
	if (wants_interact or wants_tool) and state == RUN:
		return Transition.new(WALK)
	if wants_interact:
		return Transition.new(INTERACT)
	if wants_tool:
		if c.tool_target_kind == TARGET_FRUIT_TREE:
			return Transition.new(INTERACT, FX_FORAGE)
		if c.tool_target_kind == TARGET_FARM and c.tool_blocked == &"":
			return Transition.new(INTERACT, FX_FARM)
		if c.tool_blocked != &"":
			return Transition.new(&"", FX_BLOCKED)
		if not c.tool_ok:
			return Transition.new(&"", FX_TIER_LOW)
		return Transition.new(MINE)

	# Jump (manual press, or a buffered press that just became possible).
	if f.jump_pressed or c.jump_buffered:
		if state == DUCK:
			if c.head_clear and c.headroom_ok:
				return Transition.new(JUMP, FX_STAND_UP)
			return Transition.new(&"", FX_LOW_CEILING)
		if c.headroom_ok:
			return Transition.new(JUMP, FX_GROUND_JUMP)
		return Transition.new(&"", FX_BUMP)

	# Auto-jump onto a 1-voxel ledge (decided by LedgeModel; never while ducking).
	if c.auto_jump_ready and state != DUCK and state != IDLE and c.headroom_ok:
		return Transition.new(JUMP, FX_GROUND_JUMP)

	match state:
		DUCK:
			if not c.wants_duck:
				if c.head_clear:
					return Transition.new(_moving_state(c))
				return Transition.new(&"", FX_LOW_CEILING)
			return Transition.new()
		IDLE:
			if c.wants_duck:
				return Transition.new(DUCK)
			if c.move_len > MOVE_THRESHOLD:
				return Transition.new(WALK)
		WALK:
			if c.wants_duck:
				return Transition.new(DUCK)
			if c.move_len <= MOVE_THRESHOLD:
				return Transition.new(IDLE)
			if c.wants_run:
				return Transition.new(RUN)
		RUN:
			if c.wants_duck:
				return Transition.new(DUCK)
			if c.move_len <= MOVE_THRESHOLD:
				return Transition.new(IDLE)
			if not c.wants_run:
				return Transition.new(WALK)
	return Transition.new()


static func _jump(f: InputFrame, c: PlayerContext) -> Transition:
	if _air_strike(f, c):
		return Transition.new(&"", FX_AIR_STRIKE)
	if c.ceiling_hit:
		return Transition.new(FALL, FX_CEILING)
	if f.jump_pressed:
		if c.air_jumps_left > 0:
			return Transition.new(JUMP, FX_AIR_JUMP)
		return Transition.new(&"", FX_BUFFER)
	if c.vertical_velocity <= 0.0:
		return Transition.new(FALL)
	return Transition.new()


static func _fall(f: InputFrame, c: PlayerContext) -> Transition:
	if c.on_floor:
		if c.exhaustion_pending:
			return Transition.new(SLEEP)
		if f.jump_pressed or c.jump_buffered:
			return Transition.new(JUMP, FX_GROUND_JUMP)
		var fx := FX_SOFT_LAND if c.fall_height > SOFT_LAND_HEIGHT else FX_LAND
		return Transition.new(_moving_state(c), fx)
	if c.ceiling_hit:
		return Transition.new(&"", FX_CEILING)
	if _air_strike(f, c):
		return Transition.new(&"", FX_AIR_STRIKE)
	if f.jump_pressed:
		if c.coyote_left > 0.0:
			return Transition.new(JUMP, FX_GROUND_JUMP)
		if c.air_jumps_left > 0:
			return Transition.new(JUMP, FX_AIR_JUMP)
		return Transition.new(&"", FX_BUFFER)
	return Transition.new()


## Single-shot dig while airborne (spec 4.2.1): no state change.
static func _air_strike(f: InputFrame, c: PlayerContext) -> bool:
	return f.use_pressed and not f.jump_pressed and c.tool_target_kind == TARGET_VOXEL and c.tool_ok and c.tool_blocked == &""


static func _mine(c: PlayerContext) -> Transition:
	if not c.mine_done:
		return Transition.new()
	if c.exhaustion_pending:
		return Transition.new(SLEEP)
	if c.is_ducking:
		return Transition.new(DUCK)
	return Transition.new(_moving_state(c))


static func _interact(c: PlayerContext) -> Transition:
	if not c.interact_done:
		return Transition.new()
	if c.interact_handoff != &"":
		return Transition.new(c.interact_handoff)
	if c.exhaustion_pending:
		return Transition.new(SLEEP)
	return Transition.new(_moving_state(c))
