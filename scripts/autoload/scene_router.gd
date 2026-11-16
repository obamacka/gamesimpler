## Zone loading and fades (spec 1.2). Zones are instanced under `zone_root`; the player is
## placed at the spawn marker named by `spawn_key` anywhere inside the zone scene.
extends Node

var zone_root: Node3D
var player: Node3D
var current_zone: Node
var current_zone_id: StringName = &""
var overrides: Dictionary = {}   # zone_id -> scene path (tests)
var fade_duration := 0.4
var busy := false

var _layer: CanvasLayer
var _fader: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fader = ColorRect.new()
	_fader.color = Color(0, 0, 0, 0)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fader)


func fade_out(duration: float = -1.0) -> void:
	await _fade(1.0, duration)


func fade_in(duration: float = -1.0) -> void:
	await _fade(0.0, duration)


func _fade(alpha: float, duration: float) -> void:
	var d := fade_duration if duration < 0.0 else duration
	if d <= 0.0:
		_fader.color.a = alpha
		return
	var tw := _fader.create_tween()
	tw.tween_property(_fader, "color:a", alpha, d)
	await tw.finished


func scene_path(zone_id: StringName) -> String:
	if overrides.has(zone_id):
		return overrides[zone_id]
	var z: TerrainZoneDef = Database.zones.get(zone_id)
	return z.scene_path if z else ""


func change_zone(zone_id: StringName, spawn_key: StringName) -> void:
	busy = true
	EventBus.zone_unloading.emit(current_zone_id)
	if is_instance_valid(current_zone):
		current_zone.queue_free()
		await get_tree().process_frame
	var packed: PackedScene = load(scene_path(zone_id))
	current_zone = packed.instantiate()
	current_zone_id = zone_id
	zone_root.add_child(current_zone)
	await get_tree().process_frame
	place_player(spawn_key)
	busy = false
	EventBus.zone_loaded.emit(zone_id)


func find_marker(key: StringName) -> Node3D:
	if not is_instance_valid(current_zone):
		return null
	return current_zone.find_child(String(key), true, false) as Node3D


func place_player(spawn_key: StringName) -> void:
	var marker := find_marker(spawn_key)
	if marker and is_instance_valid(player):
		player.global_position = marker.global_position
		if player is CharacterBody3D:
			player.velocity = Vector3.ZERO


## Zone travel with the transition pause (mine entrance, doors).
func travel(zone_id: StringName, spawn_key: StringName) -> void:
	PauseManager.request_pause(PauseManager.TRANSITION)
	await fade_out()
	await change_zone(zone_id, spawn_key)
	await fade_in()
	PauseManager.release_pause(PauseManager.TRANSITION)


func reset_for_tests() -> void:
	if is_instance_valid(current_zone):
		current_zone.queue_free()
	current_zone = null
	current_zone_id = &""
	overrides.clear()
	busy = false
	_fader.color.a = 0.0
