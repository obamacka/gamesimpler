## Pet AI (spec 4.6). Pure: update() takes this tick's facts and returns the state.
## Facts: {"dist": float, "player_moving": bool, "player_resting": bool (sitting or asleep),
##   "has_path": bool, "zone_changed": bool, "emote": bool, "pat": bool, "feed": bool,
##   "bowl_food": bool, "fed_today": bool, "bed_dist": float, "call": bool, "reached": bool}
class_name PetBrainModel
extends RefCounted

const FOLLOW := &"follow"
const IDLE := &"idle"
const WANDER := &"wander"
const TELEPORT := &"teleport"
const REACT := &"react"
const EAT := &"eat"
const GO_TO_BOWL := &"go_to_bowl"
const NAP := &"nap"
const CALL := &"call"

var follow_distance := 2.5
var teleport_distance := 20.0
var idle_after := 2.0
var wander_after := 6.0
var wander_leave := 6.0
var react_seconds := 1.5
var eat_seconds := 2.0
var path_timeout := 2.0
var call_path_timeout := 1.0
var call_teleport_distance := 10.0
var nap_bed_distance := 10.0

const EPS := 0.0001

var state: StringName = FOLLOW
var player_idle_t := 0.0
var no_path_t := 0.0
var state_t := 0.0


func configure(sp: PetSpeciesDef, cfg: Dictionary) -> void:
	follow_distance = sp.follow_distance
	teleport_distance = sp.teleport_distance
	idle_after = sp.idle_after
	wander_after = sp.wander_after
	react_seconds = float(cfg.get("react_seconds", react_seconds))
	eat_seconds = float(cfg.get("eat_seconds", eat_seconds))
	path_timeout = float(cfg.get("path_timeout", path_timeout))
	call_path_timeout = float(cfg.get("call_path_timeout", call_path_timeout))
	call_teleport_distance = float(cfg.get("call_teleport_distance", call_teleport_distance))
	nap_bed_distance = float(cfg.get("nap_bed_distance", nap_bed_distance))


func _go(s: StringName) -> StringName:
	if s != state:
		state = s
		state_t = 0.0
		no_path_t = 0.0
	return state


func update(delta: float, f: Dictionary) -> StringName:
	state_t += delta
	var moving: bool = f.get("player_moving", false)
	player_idle_t = 0.0 if moving else player_idle_t + delta
	var dist: float = f.get("dist", 0.0)
	if f.get("zone_changed", false):
		return _go(TELEPORT)
	match state:
		TELEPORT:
			return _go(FOLLOW)
		REACT:
			return _go(FOLLOW) if state_t + EPS >= react_seconds else state
		EAT:
			return _go(FOLLOW) if state_t + EPS >= eat_seconds else state
	if f.get("feed", false):
		return _go(EAT)
	if f.get("call", false) and state in [FOLLOW, IDLE, WANDER, NAP]:
		return _go(CALL)
	if (f.get("emote", false) or f.get("pat", false)) and state in [FOLLOW, IDLE]:
		return _go(REACT)
	match state:
		FOLLOW:
			no_path_t = 0.0 if f.get("has_path", true) else no_path_t + delta
			if dist > teleport_distance or no_path_t + EPS >= path_timeout:
				return _go(TELEPORT)
			if player_idle_t > idle_after and dist < follow_distance:
				return _go(IDLE)
		IDLE:
			if moving:
				return _go(FOLLOW)
			if f.get("bowl_food", false) and not f.get("fed_today", true):
				return _go(GO_TO_BOWL)
			if f.get("player_resting", false) and float(f.get("bed_dist", INF)) <= nap_bed_distance:
				return _go(NAP)
			if player_idle_t > wander_after:
				return _go(WANDER)
		WANDER:
			if moving or dist > wander_leave:
				return _go(FOLLOW)
		GO_TO_BOWL:
			if f.get("reached", false):
				return _go(EAT)
		NAP:
			if moving:
				return _go(FOLLOW)
		CALL:
			if f.get("reached", false):
				return _go(FOLLOW)
			no_path_t = 0.0 if f.get("has_path", true) else no_path_t + delta
			if dist > call_teleport_distance or no_path_t + EPS >= call_path_timeout:
				return _go(TELEPORT)
	return state
