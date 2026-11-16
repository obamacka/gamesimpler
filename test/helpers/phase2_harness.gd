## Builds a GameSession, zone root, fixture zones and a player for Phase 2+ integration
## suites (spec 8.2 items 2, 3, 10). Fades are instant; the yawn is skipped.
class_name Phase2Harness
extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ZONES := {
	&"zone_wilderness": "res://test/integration/scenes/fixture_wilderness.tscn",
	&"zone_starter_cabin": "res://test/integration/scenes/fixture_cabin.tscn",
	&"zone_deep_mine": "res://test/integration/scenes/fixture_deep_mine.tscn",
}

var suite: Node
var session: GameSession
var world: FakeVoxelWorld
var zone_root: Node3D
var player: PlayerController


func _init(test_suite: Node) -> void:
	suite = test_suite


## Creates everything and loads `zone_id` with the player at `spawn_key`.
func start(zone_id: StringName = &"zone_wilderness", spawn_key: StringName = &"spawn_start", seed_value: int = 918273) -> void:
	Settings.model.reset()
	PauseManager.reset_for_tests()
	SceneRouter.reset_for_tests()
	SceneRouter.fade_duration = 0.0
	SaveService.autosave_count = 0
	GameClock.running = false
	world = FakeVoxelWorld.new()
	session = GameSession.create(seed_value, world)
	suite.add_child(session)
	session.new_game()
	GameClock.model.set_time(5, 14 * 60)
	zone_root = Node3D.new()
	zone_root.name = "ZoneRoot"
	suite.add_child(zone_root)
	session.zone_root = zone_root
	SceneRouter.zone_root = zone_root
	SceneRouter.overrides = ZONES.duplicate()
	player = PLAYER_SCENE.instantiate()
	suite.add_child(player)
	player.yawn_seconds = 0.0
	player.tool_selector.set_aim_for_tests(Vector3(0, 1000, 0), Vector3.UP)   # no camera aim in tests
	SceneRouter.player = player
	await SceneRouter.change_zone(zone_id, spawn_key)
	await PhysicsWait.frames(suite.get_tree(), 5)


func stop() -> void:
	if is_instance_valid(session):
		session.stamina.exhaustion_pending = false
	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_DISABLED
	PauseManager.reset_for_tests()
	SceneRouter.reset_for_tests()
	GameClock.running = false
	Settings.model.reset()
	for n in [player, zone_root, session]:
		if is_instance_valid(n):
			n.queue_free()
	SceneRouter.player = null
	SceneRouter.zone_root = null


func vid(material_id: StringName) -> int:
	return Database.voxel_id_of(material_id)


## Aims the tool selector from the player's eyes at the center of `cell`.
func aim_at_cell(cell: Vector3i) -> void:
	var eye := player.global_position + Vector3(0, 1.95, 0)
	player.tool_selector.set_aim_for_tests(eye, (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) - eye)


func aim_at_sky() -> void:
	player.tool_selector.set_aim_for_tests(player.global_position + Vector3(0, 1.95, 0), Vector3.UP)


func place(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO


func frame(fields: Dictionary = {}) -> InputFrame:
	var f := InputFrame.new()
	for k in fields:
		f.set(k, fields[k])
	return f


func press(field: String, extra: Dictionary = {}) -> void:
	var d := extra.duplicate()
	d[field] = true
	player.input_reader.inject_once(frame(d))


func hold(fields: Dictionary = {}) -> void:
	player.input_reader.inject_hold(frame(fields))


func frames(n: int) -> void:
	await PhysicsWait.frames(suite.get_tree(), n)


func add_scene_node(node: Node3D, pos: Vector3) -> Node3D:
	SceneRouter.current_zone.add_child(node)
	node.global_position = pos
	return node
