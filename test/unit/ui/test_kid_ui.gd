# PB6: picture-first UI pieces (spec 12.4): theme, icons, tiles, item pictures.
extends GdUnitTestSuite

const USED_ICONS := ["right", "plus", "gear", "power", "home", "save", "open", "exitLeft", "checkmark", "cross", "arrowDown"]


func test_theme_is_big_rounded_and_has_a_strong_focus_outline() -> void:
	var t := KidTheme.build(1.5)
	assert_int(t.default_font_size).is_equal(int(round(KidTheme.BASE_FONT * 1.5)))
	var focus := t.get_stylebox("focus", "Button") as StyleBoxFlat
	assert_that(focus.border_color).is_equal(KidTheme.FOCUS)
	assert_int(focus.border_width_left).is_greater_equal(6)
	var normal := t.get_stylebox("normal", "Button") as StyleBoxFlat
	assert_int(normal.corner_radius_top_left).is_greater_equal(16)


## Regression: menus live in CanvasLayers, which the root window's theme does not reach.
func test_buttons_in_a_canvas_layer_get_the_kid_theme() -> void:
	var a: Accessibility = auto_free(Accessibility.new())
	add_child(a)
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	add_child(layer)
	var b := Button.new()
	layer.add_child(b)
	var focus := b.get_theme_stylebox("focus") as StyleBoxFlat
	assert_object(focus).is_not_null()
	assert_that(focus.border_color).is_equal(KidTheme.FOCUS)
	assert_int(b.get_theme_font_size("font_size")).is_equal(int(round(KidTheme.BASE_FONT * Accessibility.text_scale())))


func test_every_icon_the_menus_use_exists() -> void:
	for n in USED_ICONS:
		assert_object(UiIcons.icon(n)).override_failure_message(n).is_not_null()
	assert_object(UiIcons.icon("no_such_icon")).is_null()


func test_tiles_and_rows_carry_pictures() -> void:
	var t: Button = auto_free(MenuBase.make_tile("Play", "right", KidTheme.GO, Vector2(200, 200)))
	assert_object(t.icon).is_not_null()
	assert_str(t.text).is_equal("Play")
	assert_that(t.custom_minimum_size).is_equal(Vector2(200, 200))
	assert_that((t.get_theme_stylebox("normal") as StyleBoxFlat).bg_color).is_equal(KidTheme.GO)
	var r: Button = auto_free(MenuBase.make_button("Stone", Color.GRAY))
	assert_object(r.icon).is_not_null()   # a colour swatch when no picture is given
	assert_int(int(r.custom_minimum_size.y)).is_greater_equal(80)
	var pic := UiIcons.tile(KidTheme.CHOOSE, "gear", 96)
	assert_int(pic.get_width()).is_equal(96)
	assert_object(UiIcons.tile(KidTheme.CHOOSE, "gear", 96)).is_same(pic)   # cached


func test_item_pictures() -> void:
	# block items show their block tile
	var block_item := &""
	for id in Database.items:
		if Database.items[id].block_material != &"":
			block_item = id
			break
	assert_str(String(block_item)).is_not_empty()
	var tile := ItemIcons.texture(block_item)
	assert_str(tile.resource_path).starts_with(VoxelLibraryBuilder.TILE_DIR)
	# items with art get a picture (a placeholder tile until rendered; headless never renders)
	assert_str(ItemIcons.model_for(Database.item(&"item_pickaxe_basic"))).ends_with(".glb")
	assert_str(ItemIcons.model_for(Database.item(&"item_piece_chair"))).contains("Chair_1")
	assert_str(ItemIcons.model_for(Database.item(&"item_seed_carrot"))).contains("Carrot")
	var pic := ItemIcons.texture(&"item_pickaxe_basic")
	assert_object(pic).is_not_null()
	assert_object(ItemIcons.texture(&"item_pickaxe_basic")).is_same(pic)


func test_latest_save_slot_is_the_newest_file() -> void:
	var old := SaveService.base_dir
	SaveService.base_dir = "user://test_tmp/latest_slot"
	VoxelPersistence.remove_dir(SaveService.base_dir)
	DirAccess.make_dir_recursive_absolute(SaveService.base_dir)
	assert_int(SaveService.latest_slot()).is_equal(-1)
	var f := FileAccess.open(SaveService.paths(2)["json"], FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	assert_int(SaveService.latest_slot()).is_equal(2)
	VoxelPersistence.remove_dir(SaveService.base_dir)
	SaveService.base_dir = old
