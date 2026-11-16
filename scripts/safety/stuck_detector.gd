## Suggests Go Home when the player pushes the stick for 20 s without moving 0.5 m while
## enclosed (spec 6.3). Pure.
class_name StuckDetector
extends RefCounted

const SECONDS := 20.0
const MIN_TRAVEL := 0.5

var _t := 0.0
var _anchor := Vector3.ZERO
var hinted := false


func update(delta: float, pushing: bool, position: Vector3, enclosed: bool) -> bool:
	if not pushing or not enclosed or position.distance_to(_anchor) > MIN_TRAVEL:
		_t = 0.0
		_anchor = position
		hinted = false
		return false
	_t += delta
	if _t >= SECONDS and not hinted:
		hinted = true
		return true
	return false
