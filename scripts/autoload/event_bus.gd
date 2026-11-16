## Global signal bus (spec 1.2, 1.5). Signal declarations only: no state, no logic.
## Events are past tense. Later phases add their signals here.
extends Node

# Input (spec 2.5)
signal input_device_changed(kind: int, glyph_set: int)
signal joypad_lost(device: int)
signal joypad_restored(device: int)

# Pause (spec 5.2)
signal game_paused
signal game_resumed
signal pause_changed(paused: bool, reasons: Array)

# Player (spec 4.1)
signal player_state_changed(from: StringName, to: StringName)

# Settings
signal settings_changed(section: StringName, key: StringName, value: Variant)
