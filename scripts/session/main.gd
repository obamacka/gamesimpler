## Main scene bootstrap (Phase 2): new session, zone root, player, HUD; starts in the cabin.
extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var session: GameSession


func _ready() -> void:
	session = GameSession.create(randi())
	add_child(session)
	session.new_game()
	if OS.is_debug_build():
		session.build.grant_debug_kit()   # plan P3.2: test plot and pieces until Phase 4 sells plots
	var zone_root := Node3D.new()
	zone_root.name = "ZoneRoot"
	$World.add_child(zone_root)
	session.zone_root = zone_root
	SceneRouter.zone_root = zone_root
	var player: PlayerController = PLAYER_SCENE.instantiate()
	$World.add_child(player)
	SceneRouter.player = player
	$UI/PromptOverlay.player = player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await SceneRouter.change_zone(Database.home_zone, &"spawn_start")
	GameClock.running = true
