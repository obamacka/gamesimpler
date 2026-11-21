# PB6: title screen, outdoor start and spawn facing, dressed world objects, picture menus
# and HUD (spec 12).
extends GdUnitTestSuite

const DIR := "user://test_tmp/first_play"

var h: Phase2Harness


func before_test() -> void:
	SaveService.base_dir = DIR
	VoxelPersistence.remove_dir(DIR)
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")


func after_test() -> void:
	VoxelPersistence.remove_dir(DIR)
	h.stop()
	await get_tree().process_frame


func _scene_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_title_tiles_without_and_with_a_save() -> void:
	for slot in [SaveService.AUTOSAVE_SLOT] + SaveService.SLOTS:
		SaveService.delete_slot(slot)
	var t: TitleScreen = auto_free(TitleScreen.new())
	add_child(t)
	await get_tree().process_frame
	assert_object(t.play_btn).is_not_null()
	assert_object(t.new_btn).is_null()            # no save yet: Play is the only way in
	assert_object(t.settings_btn).is_not_null()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(t.play_btn)
	assert_bool((await SaveService.save_slot(1, h.session)).ok).is_true()
	t.refresh()
	await get_tree().process_frame
	assert_object(t.new_btn).is_not_null()        # a save exists: New appears, with a confirm
	var seen := []
	t.play_pressed.connect(func(): seen.append(&"play"))
	t.play_btn.pressed.emit()
	assert_array(seen).contains_exactly([&"play"])
	t.new_btn.pressed.emit()
	await get_tree().process_frame
	assert_str(h.menus.top().menu_id).is_equal(&"confirm")
	assert_object(get_viewport().gui_get_focus_owner()).is_same(h.menus.top().no)   # safe default
	h.menus.close_all()


func test_new_game_starts_outdoors_facing_the_marker() -> void:
	assert_str(Database.new_game_zone).is_equal(&"zone_home_meadow")
	var text := _scene_text("res://scenes/zones/home_meadow.tscn")
	assert_str(text).contains('[node name="%s"' % Database.new_game_spawn)
	# a turned marker in the current zone: the player and the camera take its facing
	var m := Marker3D.new()
	m.name = "spawn_turned"
	m.rotation.y = PI * 0.5
	SceneRouter.current_zone.add_child(m)
	m.global_position = h.player.global_position + Vector3(1, 0, 0)
	SceneRouter.place_player(&"spawn_turned")
	var fwd := -m.global_transform.basis.z
	var yaw := atan2(-fwd.x, -fwd.z)
	assert_float(h.player.camera_rig.yaw).is_equal_approx(yaw, 0.001)
	assert_float(h.player.visual.rotation.y).is_equal_approx(yaw, 0.001)


func test_every_scene_model_property_follows_its_script() -> void:
	# Regression: properties written before `script =` are dropped when the scene loads.
	for f in ["home_meadow", "starter_cabin", "museum", "wilderness", "orchard", "deep_mine"]:
		var text := _scene_text("res://scenes/zones/%s.tscn" % f)
		for block in text.split("\n[node "):
			var model_at := block.find("\nmodel = ")
			if model_at < 0:
				continue
			var script_at := block.find("\nscript = ")
			assert_bool(script_at >= 0 and script_at < model_at).override_failure_message("%s: %s" % [f, block.get_slice("\n", 0)]).is_true()
			var path := block.substr(model_at + 9).get_slice("\n", 0).trim_prefix('"').trim_suffix('"')
			assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()


func test_decor_prop_fits_collides_and_protects_its_ground() -> void:
	var d := DecorProp.new()
	d.name = "TestTree"
	d.model = ArtPaths.tree(0)
	d.size = Vector3(2.6, 4.8, 2.6)
	SceneRouter.current_zone.add_child(d)
	await get_tree().process_frame
	assert_object(d.art).is_not_null()
	var b := WorldObject.art_bounds(d.art)
	assert_bool(b.size.x <= 2.61 and b.size.y <= 4.81 and b.size.z <= 2.61).is_true()
	assert_float(b.position.y).is_equal_approx(0.0, 0.01)
	assert_bool(d.get_children().any(func(c): return c is StaticBody3D)).is_true()
	var furniture := DecorProp.new()
	furniture.model = "res://assets/third_party/quaternius/props/Chair_1.gltf"
	furniture.use_world_scale = true
	SceneRouter.current_zone.add_child(furniture)
	assert_float((furniture.art.get_child(0) as Node3D).transform.basis.get_scale().x).is_equal_approx(ModelFit.WORLD_SCALE, 0.0001)
	d.queue_free()
	furniture.queue_free()


func test_world_objects_use_models() -> void:
	var zone := SceneRouter.current_zone
	var well := Well.new()
	zone.add_child(well)
	assert_object(well.get_node_or_null("Art")).is_not_null()
	var chest := TreasureChest.new()
	chest.key = "test_chest"
	zone.add_child(chest)
	assert_object(chest.get_node_or_null("Art")).is_not_null()
	var shell := BuildingShell.new()
	shell.model = ArtPaths.PROPS + "Crate_Wooden.gltf"
	shell.size = Vector3(7, 6, 6)
	zone.add_child(shell)
	assert_object(shell.art).is_not_null()
	var body: StaticBody3D = shell.get_children().filter(func(c): return c is StaticBody3D)[0]
	var col := (body.get_child(0) as CollisionShape3D).shape as BoxShape3D
	assert_bool(col.size.is_equal_approx(WorldObject.art_bounds(shell.art).size)).is_true()   # collider follows the model
	# a village house at 1 m per unit: the collider is its walls, not the roof overhang (spec 12.8)
	var house := BuildingShell.new()
	house.model = ArtPaths.BUILDINGS + "cabin.tscn"
	house.model_scale = 1.0
	zone.add_child(house)
	var hbody: StaticBody3D = house.get_children().filter(func(c): return c is StaticBody3D)[0]
	assert_vector(((hbody.get_child(0) as CollisionShape3D).shape as BoxShape3D).size).is_equal_approx(Vector3(6, 3, 4), Vector3.ONE * 0.01)
	house.queue_free()
	var door := MineEntrance.new()
	door.target_zone = &"zone_starter_cabin"
	zone.add_child(door)
	assert_object(door.mat).is_not_null()                         # zone doors glow on the ground
	assert_object(door.get_node_or_null("Art")).is_null()
	for n in [well, chest, shell, door]:
		n.queue_free()


func test_pause_menu_is_a_picture_grid_with_title() -> void:
	var m: MenuBase = h.menus.push(&"pause_menu")
	var tiles: Array = m.get("grid").get_children()
	assert_int(tiles.size()).is_equal(6)
	assert_array(tiles.map(func(b): return b.text)).contains_exactly(["Play", "Home", "Save", "Load", "Settings", "Title"])
	assert_bool(tiles.all(func(b): return b.icon != null)).is_true()
	await get_tree().process_frame
	assert_object(get_viewport().gui_get_focus_owner()).is_same(m.resume_btn)
	(tiles[5] as Button).pressed.emit()
	assert_str(h.menus.top().menu_id).is_equal(&"confirm")
	h.menus.close_all()


func test_hud_shows_pictures_and_numbers() -> void:
	var hud := CanvasLayer.new()
	hud.set_script(load("res://ui/hud/hud.gd"))
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_str(hud._day.text).is_equal("Day %d" % GameClock.model.day)
	assert_str(hud._coins.text).is_equal(str(h.session.wallet.model.coins))
	assert_bool(hud._mail_pill.visible).is_equal(h.session.mail.model.unread_count() > 0)
	h.session.toolbelt.equip(ToolTypes.PICKAXE, &"test")
	await get_tree().process_frame
	assert_object(hud._tool_pic.texture).is_not_null()
	hud.toast("Hello")
	await get_tree().process_frame
	assert_bool(hud._toast_panel.visible).is_true()
	hud.queue_free()


func test_debug_overlay_hidden_by_default() -> void:
	var o: CanvasLayer = (load("res://ui/debug/debug_overlay.tscn") as PackedScene).instantiate()
	add_child(o)
	assert_bool(o.visible).is_false()
	o.queue_free()
