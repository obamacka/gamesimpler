## Main scene (spec 12.1): boots into the title screen; Play builds the session, the zone root
## and the player, then continues the newest save or starts a new game outdoors (spec 12.2).
## Title from the pause menu autosaves and reloads this scene.
extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var session: GameSession
var title: TitleScreen
var backdrop: TitleBackdrop
var starting := false


func _ready() -> void:
	add_to_group(&"main")
	show_title()
	# Smoke tests and screenshots: `-- --autoplay` presses Play after a moment (debug builds).
	if OS.is_debug_build() and "--autoplay" in OS.get_cmdline_user_args():
		get_tree().create_timer(2.0).timeout.connect(func(): start_game(-1))


func _exit_tree() -> void:
	if GameSession.current == session:
		GameSession.current = null


func show_title() -> void:
	_set_game_ui(false)
	backdrop = TitleBackdrop.new()
	backdrop.name = "TitleBackdrop"
	$World.add_child(backdrop)
	title = TitleScreen.new()
	title.name = "Title"
	$UI.add_child(title)
	title.play_pressed.connect(func(): start_game(SaveService.latest_slot()))
	title.new_pressed.connect(func(): start_game(-1))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _set_game_ui(on: bool) -> void:
	for n in ["UI/HUD", "UI/PromptOverlay"]:
		var c := get_node_or_null(n) as CanvasLayer
		if c:
			c.visible = on


## slot >= 0: continue that save; -1: a new game.
func start_game(slot: int) -> void:
	if starting:
		return
	starting = true
	await SceneRouter.fade_out()
	title.queue_free()
	backdrop.queue_free()
	session = GameSession.create(randi())
	add_child(session)
	var zone_root := Node3D.new()
	zone_root.name = "ZoneRoot"
	$World.add_child(zone_root)
	session.zone_root = zone_root
	SceneRouter.zone_root = zone_root
	var player: PlayerController = PLAYER_SCENE.instantiate()
	$World.add_child(player)
	SceneRouter.player = player
	$UI/PromptOverlay.player = player
	var loaded := false
	if slot >= 0:
		var r: Result = await SaveService.load_into(slot, session)
		loaded = r.ok
	if not loaded:
		SaveService.begin_new_game()   # spec 9.6: a new game streams from an empty working copy
		session.new_game()
		if OS.is_debug_build():
			session.build.grant_debug_kit()   # plan P3.2: test plot and pieces
		await SceneRouter.change_zone(Database.new_game_zone, Database.new_game_spawn)
	_set_game_ui(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameClock.running = true
	await SceneRouter.fade_in()


## Pause menu Title tile (spec 12.1): autosave, then back to a fresh title screen.
func return_to_title() -> void:
	if session:
		await SaveService.autosave(session)
	if MenuStack.instance:
		MenuStack.instance.close_all()
	GameClock.running = false
	PauseManager.release_all()
	SceneRouter.player = null
	SceneRouter.zone_root = null
	SceneRouter.current_zone = null
	get_tree().reload_current_scene()
