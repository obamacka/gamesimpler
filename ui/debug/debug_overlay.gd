## Phase 1 debug overlay (plan P1.20): player state, input device, glyph set, fps.
extends CanvasLayer

const GLYPH_NAMES := ["Xbox", "PlayStation", "Nintendo", "Keyboard/Mouse"]

var _state := "idle"
var _device := "Keyboard/Mouse"
var _glyphs := "Keyboard/Mouse"

@onready var label: Label = $Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.player_state_changed.connect(func(_from, to): _state = String(to))
	EventBus.input_device_changed.connect(_on_device)


func _on_device(kind: int, glyph_set: int) -> void:
	_device = "Gamepad" if kind == InputDeviceModel.DeviceKind.GAMEPAD else "Keyboard/Mouse"
	_glyphs = GLYPH_NAMES[glyph_set]


func _process(_delta: float) -> void:
	label.text = "state: %s\ndevice: %s\nglyphs: %s\nfps: %d" % [_state, _device, _glyphs, Engine.get_frames_per_second()]
