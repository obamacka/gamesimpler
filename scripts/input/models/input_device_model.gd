## Active device and glyph-set logic (spec 2.5), free of engine singletons so it can be
## unit-tested with constructed events.
class_name InputDeviceModel
extends RefCounted

enum DeviceKind { KEYBOARD_MOUSE, GAMEPAD }
enum GlyphSet { XBOX, PLAYSTATION, NINTENDO, KBM }

const MOUSE_MOTION_THRESHOLD_PX := 4.0
const JOY_AXIS_THRESHOLD := 0.5

const VENDOR_SONY := 0x054C
const VENDOR_MICROSOFT := 0x045E
const VENDOR_NINTENDO := 0x057E

var kind: DeviceKind = DeviceKind.KEYBOARD_MOUSE
var pad_glyphs: GlyphSet = GlyphSet.XBOX
var glyph_override := -1   # -1 = automatic, else a GlyphSet value applied to gamepads
var active_joypad := -1


## Returns the device kind an event indicates, or -1 if the event is too small to count.
static func classify(event: InputEvent) -> int:
	if event is InputEventKey or event is InputEventMouseButton:
		return DeviceKind.KEYBOARD_MOUSE
	if event is InputEventMouseMotion:
		return DeviceKind.KEYBOARD_MOUSE if event.relative.length() > MOUSE_MOTION_THRESHOLD_PX else -1
	if event is InputEventJoypadButton:
		return DeviceKind.GAMEPAD
	if event is InputEventJoypadMotion:
		return DeviceKind.GAMEPAD if absf(event.axis_value) > JOY_AXIS_THRESHOLD else -1
	return -1


static func glyphs_for_vendor(vendor_id: int) -> GlyphSet:
	match vendor_id:
		VENDOR_SONY:
			return GlyphSet.PLAYSTATION
		VENDOR_NINTENDO:
			return GlyphSet.NINTENDO
		_:
			return GlyphSet.XBOX


## The glyph set the UI should show right now.
func current_glyphs() -> GlyphSet:
	if kind == DeviceKind.KEYBOARD_MOUSE:
		return GlyphSet.KBM
	if glyph_override >= 0:
		return glyph_override as GlyphSet
	return pad_glyphs


## Feeds one event. `vendor_id` is the joypad's USB vendor id (0 if unknown or not a pad).
## Returns true if the device kind or the shown glyph set changed.
func feed(event: InputEvent, vendor_id: int = 0) -> bool:
	var k := classify(event)
	if k < 0:
		return false
	var before_kind := kind
	var before_glyphs := current_glyphs()
	kind = k as DeviceKind
	if k == DeviceKind.GAMEPAD:
		active_joypad = event.device
		pad_glyphs = glyphs_for_vendor(vendor_id)
	return kind != before_kind or current_glyphs() != before_glyphs
