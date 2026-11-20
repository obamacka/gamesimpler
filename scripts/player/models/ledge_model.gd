## Auto-jump decision (spec 4.2.1, D18). Probe results come from PlayerController.
class_name LedgeModel
extends RefCounted

const TOWARD_TIME := 0.3          # seconds moving into the ledge before auto-jumping
const MANUAL_JUMP_COOLDOWN := 0.5 # no auto-jump right after a manual jump


## step_solid: the cell in front at foot level is solid.
## above_free: the cell above that step is free (so it is a 1-high step).
## clearance_free: the standing capsule fits above the step top (2 cells for the 1.7 m player).
static func should_auto_jump(
		enabled: bool, on_floor: bool, ducking: bool,
		step_solid: bool, above_free: bool, clearance_free: bool,
		toward_time: float, since_manual_jump: float) -> bool:
	return enabled and on_floor and not ducking \
		and step_solid and above_free and clearance_free \
		and toward_time >= TOWARD_TIME and since_manual_jump >= MANUAL_JUMP_COOLDOWN
