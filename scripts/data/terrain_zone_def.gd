## Zone definition (spec 3.4, 9.2).
class_name TerrainZoneDef
extends Resource

const OVERWORLD := &"OVERWORLD"
const DEEP_MINE := &"DEEP_MINE"
const STATIC := &"STATIC"

@export var id: StringName
@export var kind: StringName = OVERWORLD
@export var scene_path := ""
@export var seed_mode: StringName = &"FIXED"
@export var persist_edits := true
@export var stream_db_key := ""
@export var bounds_min := Vector3i(-64, -32, -64)
@export var bounds_max := Vector3i(64, 64, 64)
@export var treasure_table: StringName = &""
