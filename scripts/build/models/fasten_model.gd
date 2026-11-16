## Screw and nail mini-game (spec 2.7, plan P3.5). Pure. No miss state exists.
## Nails: each press is one hit (`hits_per_socket` hits). Screws: hold 0.8 s per socket.
## HOLD mode turns nail hits into 0.4 s holds. Progress survives release and cancel.
class_name FastenModel
extends RefCounted

const ANGLES := [4.0, 6.0, 9.0]   # reticle snap angle per snap strength
const SCREW_HOLD := 0.8
const NAIL_HOLD := 0.4

const NONE := &"none"
const HIT := &"hit"
const SOCKET_DONE := &"socket_done"
const DONE := &"done"

var positions: Array[Vector3] = []
var fastener: StringName = BuildPieceDef.NAILS
var hits_needed := 2
var hold_mode := false
var hits: Array[int] = []
var current := -1
var _hold := 0.0


func setup(socket_positions: Array[Vector3], p_fastener: StringName, hits_per_socket: int, p_hold_mode: bool, progress: Array = []) -> void:
	positions = socket_positions.duplicate()
	fastener = p_fastener
	hits_needed = 1 if fastener == BuildPieceDef.SCREWS else maxi(1, hits_per_socket)
	hold_mode = p_hold_mode
	hits.clear()
	for i in positions.size():
		hits.append(int(progress[i]) if i < progress.size() else 0)
	current = -1
	_hold = 0.0


func steps_total() -> int:
	return positions.size() * hits_needed


func steps_done() -> int:
	var n := 0
	for h in hits:
		n += mini(h, hits_needed)
	return n


func is_done() -> bool:
	return steps_done() >= steps_total()


func socket_done(i: int) -> bool:
	return hits[i] >= hits_needed


func uses_hold() -> bool:
	return fastener == BuildPieceDef.SCREWS or hold_mode


func hold_seconds() -> float:
	return SCREW_HOLD if fastener == BuildPieceDef.SCREWS else NAIL_HOLD


## Snaps the reticle to the unfinished socket with the smallest angle to the aim ray, within
## `angle_deg`. Keeps the current socket if it is still within the angle.
func aim(origin: Vector3, direction: Vector3, angle_deg: float) -> int:
	var dir := direction.normalized()
	if current >= 0 and not socket_done(current) and _angle(origin, dir, positions[current]) <= angle_deg:
		return current
	var best := -1
	var best_a := INF
	for i in positions.size():
		if socket_done(i):
			continue
		var a := _angle(origin, dir, positions[i])
		if a <= angle_deg and a < best_a - 0.0001:
			best = i
			best_a = a
	if best != current:
		_hold = 0.0
	current = best
	return current


static func _angle(origin: Vector3, dir: Vector3, p: Vector3) -> float:
	var to := p - origin
	if to.length_squared() < 0.000001:
		return 0.0
	return rad_to_deg(dir.angle_to(to.normalized()))


## One hammer press (press mode for nails).
func press() -> StringName:
	if current < 0 or uses_hold():
		return NONE
	return _hit()


## Hold progress for screws (or nails in HOLD mode).
func hold(delta: float) -> StringName:
	if current < 0 or not uses_hold():
		return NONE
	_hold += delta
	if _hold + 0.000001 < hold_seconds():
		return NONE
	_hold = 0.0
	return _hit()


func hold_fraction() -> float:
	return clampf(_hold / hold_seconds(), 0.0, 1.0)


func _hit() -> StringName:
	hits[current] += 1
	if not socket_done(current):
		return HIT
	if is_done():
		current = -1
		return DONE
	current = next_socket(current)
	return SOCKET_DONE


## Auto-advance: the nearest unfinished socket to `from` (ties by index).
func next_socket(from: int) -> int:
	var best := -1
	var best_d := INF
	for i in positions.size():
		if socket_done(i):
			continue
		var d := positions[from].distance_to(positions[i])
		if d < best_d - 0.000001:
			best = i
			best_d = d
	return best


func progress() -> Array:
	return hits.duplicate()
