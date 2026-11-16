## Build sub-FSM (spec 4.4, plan P3.7). Pure. Tools cycle Place -> Paint -> Stamp; Paint and
## Stamp exist but are disabled until Phase 6. Place has Preview, Fasten and Removing.
class_name BuildModel
extends RefCounted

const PLACE := &"place"
const PAINT := &"paint"
const STAMP := &"stamp"
const TOOLS: Array[StringName] = [PLACE, PAINT, STAMP]
const PREVIEW := &"preview"
const FASTEN := &"fasten"
const REMOVING := &"removing"

var tool: StringName = PLACE
var sub: StringName = PREVIEW
var remove_hold := 0.6
var remove_t := 0.0
var catalog_open := false
## Selected placeable: {"kind": &"piece" | &"block", "id": StringName}
var selected: Dictionary = {}
var manual_rot := 0
# Paint and Stamp tools (spec 7.2)
var paint_region := 0          # index into the aimed piece's paint regions
var dye: StringName = &""
var sticker: StringName = &""
var stamp_rot := 0             # degrees, 45 steps
var stamp_size := "M"


func reset() -> void:
	tool = PLACE
	sub = PREVIEW
	remove_t = 0.0
	catalog_open = false


func tool_enabled() -> bool:
	return tool in TOOLS


func next_tool() -> void:
	_leave_sub()
	tool = TOOLS[(TOOLS.find(tool) + 1) % TOOLS.size()]


func prev_tool() -> void:
	_leave_sub()
	tool = TOOLS[(TOOLS.find(tool) + TOOLS.size() - 1) % TOOLS.size()]


func _leave_sub() -> void:
	sub = PREVIEW
	remove_t = 0.0


## RB/LB: rotate the ghost (Place), cycle the paint region (Paint), turn the stamp 45 degrees
## (Stamp) (spec 2.3).
func rotate(step: int) -> void:
	match tool:
		PLACE:
			manual_rot = posmod(manual_rot + step, 4)
		PAINT:
			paint_region += step
		STAMP:
			stamp_rot = posmod(stamp_rot + step * 45, 360)


func begin_fasten() -> bool:
	if tool != PLACE or sub != PREVIEW:
		return false
	sub = FASTEN
	return true


func end_fasten() -> void:
	if sub == FASTEN:
		sub = PREVIEW


## LT held on own piece or placed block. Returns true on the tick removal completes.
## LT held: remove a piece or block (Place) or the nearest stamp (Stamp).
func tick_remove(delta: float, alt_held: bool, has_target: bool) -> bool:
	if tool == PAINT:
		return false
	if sub == PREVIEW and alt_held and has_target:
		sub = REMOVING
		remove_t = 0.0
	if sub != REMOVING:
		return false
	if not alt_held or not has_target:
		sub = PREVIEW
		remove_t = 0.0
		return false
	remove_t += delta
	if remove_t + 0.000001 >= remove_hold:
		sub = PREVIEW
		remove_t = 0.0
		return true
	return false


func open_catalog() -> void:
	catalog_open = true


## The catalog returns to the same tool and sub-state (spec 4.4).
func close_catalog(choice: Dictionary = {}) -> void:
	catalog_open = false
	if not choice.is_empty():
		selected = choice
