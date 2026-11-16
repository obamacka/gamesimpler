## World and player facts the transition table needs each tick (spec 4.1).
## Filled by PlayerController from probes, timers and settings.
class_name PlayerContext
extends RefCounted

var move_len := 0.0
var wants_run := false
var wants_duck := false
var is_ducking := false
var head_clear := true         # standing capsule fits (HeadClearance)
var headroom_ok := true        # room above the head to jump
var on_floor := true
var vertical_velocity := 0.0
var ceiling_hit := false
var coyote_left := 0.0
var jump_buffered := false
var air_jumps_left := 1
var auto_jump_ready := false   # LedgeModel decided an auto-jump should fire this tick
var fall_height := 0.0
var exhaustion_pending := false
