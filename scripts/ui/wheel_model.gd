## Radial wheel (spec 4.8). Pure: stick direction -> slot, with a dead zone; releasing on
## neutral cancels. Slot 0 is straight up, counted clockwise.
class_name WheelModel
extends RefCounted

const DEAD_ZONE := 0.6

var slots := 8
var hovered := -1


static func slot_for(dir: Vector2, count: int = 8, dead_zone: float = DEAD_ZONE) -> int:
	if dir.length() < dead_zone:
		return -1
	var ang := atan2(dir.x, -dir.y)   # 0 = up (y negative is up for sticks and screens)
	var step := TAU / count
	return posmod(int(round(ang / step)), count)


func hover(dir: Vector2) -> int:
	var s := slot_for(dir, slots)
	if s >= 0:
		hovered = s
	return hovered


## Release: commits the hovered slot if the stick is still deflected, else cancels (-1).
func release(dir: Vector2) -> int:
	var s := slot_for(dir, slots)
	hovered = -1
	return s
