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
const BUILD := &"build"
const SIT := &"sit"
const CRAFT := &"craft"
const TALK := &"talk"
const EMOTE := &"emote"
const PLAY_INSTRUMENT := &"playinstrument"

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
const FX_NO_BUILD_ZONE := &"no_build_zone"
const FX_BUILD_EXIT := &"build_exit"
const FX_STAND := &"stand"

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
	if state == BUILD:
		return _build(f, c)
	if state == SIT:
		return _sit(f, c)
	if state == CRAFT:
		return _craft(f, c)
	if state == TALK:
		return Transition.new(IDLE) if c.talk_done else Transition.new()
	if state == EMOTE:
		return Transition.new(_moving_state(c)) if c.emote_done or c.move_len > MOVE_THRESHOLD else Transition.new()
	if state == PLAY_INSTRUMENT:
		return Transition.new(_moving_state(c)) if c.move_len > MOVE_THRESHOLD or f.wheel_pressed else Transition.new()
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

	# Wheel choices (spec 4.8): emote from Idle/Walk, instrument from Idle/Walk.
	if c.pending_emote and (state == IDLE or state == WALK):
		return Transition.new(EMOTE)
	if c.pending_instrument and (state == IDLE or state == WALK):
		return Transition.new(PLAY_INSTRUMENT)

	# Build mode (spec 4.2): only inside an owned plot or job site.
	if f.build_toggle_pressed and state != DUCK and state != RUN:
		if c.in_build_zone:
			return Transition.new(BUILD)
		return Transition.new(&"", FX_NO_BUILD_ZONE)

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
		if c.build_active and not (f.jump_pressed or c.jump_buffered):
			return Transition.new(BUILD, FX_LAND)
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
	return f.use_pressed and not f.jump_pressed and not c.build_active and c.tool_target_kind == TARGET_VOXEL and c.tool_ok and c.tool_blocked == &""


## Build (spec 4.2, 2.3): walk, jump (Build stays active in the air), exit on D-pad up or B.
## B while fastening cancels the fasten instead (handled by the BuildController).
static func _build(f: InputFrame, c: PlayerContext) -> Transition:
	if c.exhaustion_pending:
		return Transition.new(SLEEP)
	if not c.on_floor and c.coyote_left <= 0.0:
		return Transition.new(FALL)
	if c.build_fastening:
		return Transition.new()
	if f.build_toggle_pressed or f.duck_pressed:
		return Transition.new(IDLE, FX_BUILD_EXIT)
	if (f.jump_pressed or c.jump_buffered) and c.headroom_ok:
		return Transition.new(JUMP, FX_GROUND_JUMP)
	return Transition.new()


## Craft (spec 4.2): done -> Idle; move or duck cancels (nothing consumed).
static func _craft(f: InputFrame, c: PlayerContext) -> Transition:
	if c.craft_done:
		return Transition.new(_moving_state(c))
	if f.duck_pressed or c.move_len > MOVE_THRESHOLD:
		return Transition.new(IDLE, FX_STAND)
	return Transition.new()


static func _sit(f: InputFrame, c: PlayerContext) -> Transition:
	if f.duck_pressed or f.jump_pressed or c.move_len > 0.5:
		return Transition.new(IDLE, FX_STAND)
	return Transition.new()


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
