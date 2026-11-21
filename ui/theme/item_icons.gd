## Item pictures for menus (spec 12.4). Block items use their block tile. Items with a model
## (world model, build piece, seed's ripe crop, outfit part) are rendered once in an offscreen
## viewport; until then, and in headless runs, the picture is a rounded tile in the item colour.
## The returned ImageTexture is updated in place when the render finishes, so buttons that
## already show it update by themselves.
class_name ItemIcons
extends Node

const SIZE := 128

static var _textures := {}    # item id -> Texture2D
static var _service: ItemIcons

var _queue: Array = []        # [item_id, model path, ImageTexture]
var _viewport: SubViewport
var _stage: Node3D
var _busy := false


static func texture(item_id: StringName) -> Texture2D:
	if _textures.has(item_id):
		return _textures[item_id]
	var it: ItemDef = Database.item(item_id)
	var tile := block_tile(it)
	if tile:
		_textures[item_id] = tile
		return tile
	var color := MenuBase.item_color(item_id)
	var placeholder := ImageTexture.create_from_image((UiIcons.tile(color, "", SIZE) as ImageTexture).get_image().duplicate())
	_textures[item_id] = placeholder
	var path := model_for(it)
	if not path.is_empty() and DisplayServer.get_name() != "headless":
		_ensure_service()
		_service._queue.append([item_id, path, placeholder])
	return placeholder


static func block_tile(it: ItemDef) -> Texture2D:
	if it == null or it.block_material == &"" or not Database.materials.has(it.block_material):
		return null
	var m: VoxelMaterialDef = Database.materials[it.block_material]
	if m.tiles.is_empty():
		return null
	return load(VoxelLibraryBuilder.TILE_DIR + m.tile("top" if m.tiles.has("top") else "side")) as Texture2D


## Scene used for an item's picture, or "".
static func model_for(it: ItemDef) -> String:
	if it == null:
		return ""
	if not it.world_model.is_empty():
		return it.world_model
	if it.piece_id != &"" and Database.pieces.has(it.piece_id) and Database.pieces[it.piece_id].has_model():
		return Database.pieces[it.piece_id].model_scene
	if it.seed_crop != &"" and Database.crops.has(it.seed_crop) and Database.crops[it.seed_crop].has_models():
		return Database.crops[it.seed_crop].models["ripe"]
	if it.outfit_id != &"" and Database.outfits.has(it.outfit_id):
		var parts: Array = Database.outfits[it.outfit_id].parts_for(CharacterRig.FEMALE)
		if not parts.is_empty():
			return CharacterRig.ROOT + "outfits/%s.gltf" % parts[0]
	return ""


static func _ensure_service() -> void:
	if is_instance_valid(_service):
		return
	_service = ItemIcons.new()
	_service.name = "ItemIcons"
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_service)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.35
	_viewport.add_child(cam)
	cam.look_at_from_position(Vector3(1.6, 1.5, 2.4), Vector3(0, 0.45, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	_viewport.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	_viewport.add_child(env)


func _process(_delta: float) -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	var job: Array = _queue.pop_front()
	await _render(job[1], job[2])
	_busy = false


func _render(path: String, target: ImageTexture) -> void:
	for c in _stage.get_children():
		c.free()
	var m := ModelFit.instantiate(path)
	if m == null:
		return
	_stage.add_child(m)
	ModelFit.fit(m, AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE), 0)
	for i in 2:
		await RenderingServer.frame_post_draw
	var img := _viewport.get_texture().get_image()
	if img and not img.is_empty():
		img.convert(Image.FORMAT_RGBA8)
		target.set_image(img)
