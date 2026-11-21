# PC5: picture-tile shop and inventory (spec 12.5), sitting on room decor (12.6), closed room
# doorways and kill planes (12.7).
extends GdUnitTestSuite

var h: Phase2Harness


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")


func after_test() -> void:
	h.stop()
	await get_tree().process_frame


func test_shop_is_a_grid_of_priced_picture_tiles() -> void:
	h.session.wallet.model.coins = 500
	var m: MenuBase = h.menus.push(&"shop", {"shop_id": &"shop_general"})
	var buy: GridContainer = m.get("buy_list")
	var shop: ShopDef = Database.shops[&"shop_general"]
	assert_int(buy.get_child_count()).is_equal(shop.stock.size())
	var tile: Button = buy.get_child(0)
	assert_object((tile.find_child("Picture", true, false) as TextureRect).texture).is_not_null()
	var id: StringName = shop.stock[0]["item"]
	assert_str((tile.find_child("Badge", true, false) as Label).text).is_equal(str(h.session.economy.tx.buy_quote(&"shop_general", id, 1)))
	var before := h.session.inventory.count(id)
	tile.pressed.emit()
	assert_int(h.session.inventory.count(id)).is_equal(before + 1)
	assert_int((m.get("sell_list") as GridContainer).get_child_count()).is_greater(0)
	assert_int(m.get("tabs").get_tab_count()).is_equal(2)
	assert_object(m.get("tabs").get_tab_icon(0)).is_not_null()
	h.menus.close_all()


func test_sold_out_or_too_dear_tiles_are_dimmed() -> void:
	var t := MenuBase.make_item_tile(&"item_apple", "", 10)
	add_child(t)
	MenuBase.set_tile_enabled(t, false)
	assert_bool(t.disabled).is_true()
	assert_float(t.modulate.a).is_less(1.0)
	t.queue_free()


func test_inventory_backpack_is_a_grid_of_slots() -> void:
	h.session.inventory.add(&"item_apple", 3)
	var m: MenuBase = h.menus.push(&"inventory")
	var grid: GridContainer = m.get("backpack")
	assert_int(grid.get_child_count()).is_equal(h.session.inventory.model.slots.size())
	var filled := 0
	for i in grid.get_child_count():
		var st = h.session.inventory.model.slots[i]
		var tile: Button = grid.get_child(i)
		var pic := tile.find_child("Picture", true, false) as TextureRect
		if st:
			filled += 1
			assert_object(pic.texture).is_not_null()
			if int(st["qty"]) > 1:
				assert_str((tile.find_child("Badge", true, false) as Label).text).is_equal("x%d" % st["qty"])
		else:
			assert_float(tile.modulate.a).is_less(1.0)   # empty slots are faint
	assert_int(filled).is_greater(0)
	h.menus.close_all()


func test_sitting_on_a_room_chair() -> void:
	var chair := DecorProp.new()
	chair.name = "RoomChair"
	chair.model = "res://assets/third_party/kaykit/furniture_bits/chair_A.gltf"
	chair.use_world_scale = true
	chair.seat_count = 1
	SceneRouter.current_zone.add_child(chair)
	chair.global_position = h.player.global_position + Vector3(0, 0, -1.6)
	chair.rotation.y = PI   # facing the player
	# seats are computed when the chair is ready; rebuild them at its new place
	chair.seats.clear()
	chair.exits.clear()
	for c in chair.get_children():
		if c is Interactable:
			chair.remove_child(c)
			c.free()
	chair._make_seats()
	assert_int(chair.seats.size()).is_equal(1)
	assert_float(chair.seats[0].y - chair.global_position.y).is_equal_approx(0.5 * ModelFit.WORLD_SCALE, 0.001)
	h.aim_at_sky()
	await h.frames(4)
	h.press("interact_pressed")
	var n := 0
	while h.player.machine.current_id != &"sit" and n < 60:
		await h.frames(1)
		n += 1
	assert_str(h.player.machine.current_id).is_equal(&"sit")
	assert_vector(h.player.global_position).is_equal_approx(chair.seats[0], Vector3.ONE * 0.01)
	h.press("jump_pressed")
	await h.frames(3)
	assert_str(h.player.machine.current_id).is_not_equal(&"sit")
	chair.queue_free()


func test_room_doorways_are_closed_and_rooms_have_kill_planes() -> void:
	for f in ["starter_cabin", "museum"]:
		var text := FileAccess.get_file_as_string("res://scenes/zones/%s.tscn" % f)
		assert_str(text).contains('[node name="DoorPanel" type="StaticBody3D"')
		assert_str(text).contains('[node name="KillPlane" type="Area3D"')
		# the door panel is as wide as the gap between the two south wall segments
		assert_str(text).contains('[sub_resource type="BoxShape3D" id="door_shape"]\nsize = Vector3(2,')
		assert_str(text).contains('[node name="WallSouthWest"')
	var cabin := FileAccess.get_file_as_string("res://scenes/zones/starter_cabin.tscn")
	for chair in ["ChairW", "ChairE", "Armchair"]:
		var i := cabin.find('[node name="%s"' % chair)
		assert_str(cabin.substr(i, 400).get_slice("\n\n", 0)).contains("seat_count = 1")
