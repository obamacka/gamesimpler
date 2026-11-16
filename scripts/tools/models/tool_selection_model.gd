## Auto-tool selection (spec 2.6, rules 1 to 11). Pure: the ToolAutoSelector node feeds it
## the aimed target and the zone candidates every physics tick and applies the events.
##
## aim: {} or {"key": String, "tool": StringName, "target_kind": StringName,
##            "tier_required": int, "blocked": StringName (&"" if diggable)}
## zones: [{"key": String, "tool": StringName, "target_kind": StringName, "priority": int,
##          "distance": float, "enter_radius": float, "inside": bool, "active": bool}]
## Events: {"type": &"equip", "tool", "target_kind", "reason"} | {"type": &"unequip"} |
##         {"type": &"prompt", "key", "state": &"missing_tool"|&"tier_lock"|<blocked reason>, "tool"}
class_name ToolSelectionModel
extends RefCounted

const DEBOUNCE := 0.15
const ZONE_HYSTERESIS := 0.5
const AIM_GRACE := 0.3
const OVERRIDE_SECONDS := 10.0
const REVERT_SECONDS := 1.0
const EPS := 0.0001

var belt: ToolBeltModel
var enabled := true
var revert_when_idle := false   # D15: keep the last tool unless this setting is on
var time := 0.0

var _candidate_keys: Dictionary = {}
var _pending_tool: StringName = &""
var _pending_since := 0.0
var _last_aim: Dictionary = {}
var _aim_lost_since := -1.0
var _no_best_since := -1.0
var _override_until := -1.0
var _was_locked := false
var _last_prompt := ""
var last_best: Dictionary = {}   # the current best target (also used by the player for actions)


func _init(b: ToolBeltModel) -> void:
	belt = b


## Manual pick from the wheel (rule 6). Returns the equip event or {} if the tool is not owned.
func manual_select(tool: StringName) -> Dictionary:
	if not belt.equip(tool):
		return {}
	_override_until = time + OVERRIDE_SECONDS
	_pending_tool = &""
	return {"type": &"equip", "tool": tool, "target_kind": &"", "reason": &"manual"}


func update(delta: float, aim: Dictionary, zones: Array, locked: bool) -> Array:
	time += delta
	var events: Array = []
	if not enabled:
		return events

	var best := _best(aim, zones, events)
	last_best = best

	# Rule 6: manual override lasts 10 s or until nothing is targeted.
	if _override_until >= 0.0:
		if time >= _override_until or best.is_empty():
			_override_until = -1.0
		else:
			return events

	# Rule 5: action lock. The switch is evaluated when the lock ends.
	if locked:
		_was_locked = true
		return events
	var lock_released := _was_locked
	_was_locked = false

	# Rule 9: nothing targeted.
	if best.is_empty():
		_pending_tool = &""
		if revert_when_idle and belt.equipped != ToolTypes.NONE:
			if _no_best_since < 0.0:
				_no_best_since = time
			elif time - _no_best_since >= REVERT_SECONDS - EPS:
				belt.unequip()
				_no_best_since = -1.0
				events.append({"type": &"unequip"})
		return events
	_no_best_since = -1.0

	var tool: StringName = best["tool"]
	# Rule 7: missing tool leaves equipment unchanged.
	if not belt.has_tool(tool):
		_prompt(events, best["key"], &"missing_tool", tool)
		_pending_tool = &""
		return events
	# Rule 8: tier too low still equips, with a badge.
	var data := belt.tool_data(tool)
	if int(best.get("tier_required", 0)) > (data.tier if data else 0):
		_prompt(events, best["key"], &"tier_lock", tool)
	elif _last_prompt.begins_with(best["key"] + ":"):
		_last_prompt = ""

	if tool == belt.equipped:
		_pending_tool = &""
		return events

	if lock_released:
		return _equip(events, best, &"lock_released")

	# Rule 3: debounce.
	if _pending_tool != tool:
		_pending_tool = tool
		_pending_since = time
		return events
	if time - _pending_since >= DEBOUNCE - EPS:
		return _equip(events, best, best["reason"])
	return events


func _equip(events: Array, best: Dictionary, reason: StringName) -> Array:
	belt.equip(best["tool"])
	_pending_tool = &""
	events.append({"type": &"equip", "tool": best["tool"], "target_kind": best["target_kind"], "reason": reason})
	return events


func _prompt(events: Array, key: String, state: StringName, tool: StringName) -> void:
	var sig := "%s:%s:%s" % [key, state, tool]
	if sig != _last_prompt:
		_last_prompt = sig
		events.append({"type": &"prompt", "key": key, "state": state, "tool": tool})


## Rules 1, 2 and 4: candidates, aim preference, priority, distance, hysteresis.
func _best(aim: Dictionary, zones: Array, events: Array) -> Dictionary:
	var current_aim := aim
	if aim.is_empty():
		if _aim_lost_since < 0.0:
			_aim_lost_since = time
		if not _last_aim.is_empty() and time - _aim_lost_since < AIM_GRACE:
			current_aim = _last_aim
	else:
		_aim_lost_since = -1.0
		_last_aim = aim

	if not current_aim.is_empty():
		var blocked: StringName = current_aim.get("blocked", &"")
		if blocked != &"":
			_prompt(events, current_aim["key"], blocked, &"")
		elif current_aim.get("tool", &"") != &"":
			return {"key": current_aim["key"], "tool": current_aim["tool"], "target_kind": current_aim["target_kind"],
				"tier_required": current_aim.get("tier_required", 0), "reason": &"aim_change"}

	var cands: Array = []
	var keep: Dictionary = {}
	for z in zones:
		if not z.get("active", true):
			continue
		var was := _candidate_keys.has(z["key"])
		if z.get("inside", false) or (was and float(z["distance"]) <= float(z["enter_radius"]) + ZONE_HYSTERESIS):
			cands.append(z)
			keep[z["key"]] = true
	_candidate_keys = keep
	if cands.is_empty():
		return {}
	cands.sort_custom(func(a, b):
		if a["priority"] != b["priority"]:
			return a["priority"] > b["priority"]
		if not is_equal_approx(a["distance"], b["distance"]):
			return a["distance"] < b["distance"]
		return a["key"] < b["key"])
	var z: Dictionary = cands[0]
	return {"key": z["key"], "tool": z["tool"], "target_kind": z["target_kind"], "tier_required": 0, "reason": &"zone_enter"}


## Equips the current best target's tool immediately (used when the player acts before the
## debounce elapsed). Returns the equip event or {}.
func commit_now() -> Dictionary:
	if last_best.is_empty() or not belt.has_tool(last_best["tool"]) or belt.equipped == last_best["tool"]:
		return {}
	belt.equip(last_best["tool"])
	_pending_tool = &""
	return {"type": &"equip", "tool": last_best["tool"], "target_kind": last_best["target_kind"], "reason": &"aim_change"}
