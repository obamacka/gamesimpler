## Phase 2 stub (plan P2.19): records autosave requests. Phase 6 replaces it with real
## JSON and voxel DB saving (spec 3.5, 9.6).
extends Node

var autosave_count := 0
var last_snapshot: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func autosave(session: GameSession) -> void:
	autosave_count += 1
	last_snapshot = session.to_dict().duplicate(true)
