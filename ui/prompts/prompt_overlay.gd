## World-anchored button prompts (spec 2.8): glyph + text over the focused target, projected
## with Camera3D.unproject_position. Hidden while paused (game_paused) and when behind the camera.
class_name PromptOverlay
extends CanvasLayer

const GLYPH := preload("res://ui/prompts/glyph_icon.tscn")

var player: PlayerController
var _box: VBoxContainer
var _paused := false


func _ready() -> void:
	layer = 20
	_box = VBoxContainer.new()
	add_child(_box)
	EventBus.game_paused.connect(func(): _paused = true; _box.visible = false)
	EventBus.game_resumed.connect(func(): _paused = false)


func _process(_delta: float) -> void:
	if _paused or not is_instance_valid(player) or GameSession.current == null:
		_box.visible = false
		return
	var target := player.prompt_target()
	var cam := player.get_viewport().get_camera_3d()
	if target.is_empty() or cam == null or cam.is_position_behind(target["position"]):
		_box.visible = false
		return
	var unread := GameSession.current.mail.model.unread_count()
	_show(PromptModel.rows(target["tool"], target["blocked"], target["primary"], target["secondary"], unread))
	_box.position = cam.unproject_position(target["position"]) + Vector2(24, -24)
	_box.visible = true


func _show(rows: Array) -> void:
	while _box.get_child_count() < rows.size():
		var row := HBoxContainer.new()
		var g := GLYPH.instantiate()
		g.custom_minimum_size = Vector2(36, 36)
		row.add_child(g)
		var l := Label.new()
		row.add_child(l)
		_box.add_child(row)
	for i in _box.get_child_count():
		var row: HBoxContainer = _box.get_child(i)
		row.visible = i < rows.size()
		if i < rows.size():
			var g: GlyphIcon = row.get_child(0)
			g.visible = rows[i]["button"] != &"lock"
			g.button = rows[i]["button"]
			g.queue_redraw()
			(row.get_child(1) as Label).text = ("[locked] " if rows[i]["button"] == &"lock" else "") + rows[i]["text"]
