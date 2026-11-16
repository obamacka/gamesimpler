# P5.19: pat, feed vs dress up, bowl self-feed, accessories on bone attachments.
extends GdUnitTestSuite

var h: Phase2Harness
var pet: Pet


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	PetFixture.setup(h)
	GameClock.model.set_time(3, 9 * 60)
	h.place(Vector3(-7.5, 0, 12.5))
	await h.frames(2)
	pet = PetFixture.adopt(h)
	h.session.pets.pet()["happiness"] = 50
	await h.frames(4)


func after_test() -> void:
	h.stop()
	await get_tree().process_frame


## Puts the pet right in front of the player (facing -z) and stops it.
func _pet_in_front() -> void:
	h.player.face_towards(h.player.global_position + Vector3(0, 0, -1))
	pet.global_position = h.player.global_position + Vector3(0, 0, -1.0)
	h.session.pets.path_override.fail = false
	await h.frames(2)


func test_x_pats_with_once_per_day_bonus() -> void:
	await _pet_in_front()
	h.press("interact_pressed")
	await h.frames(70)
	assert_int(h.session.pets.pet()["happiness"]).is_equal(55)
	await _pet_in_front()
	h.press("interact_pressed")
	await h.frames(70)
	assert_int(h.session.pets.pet()["happiness"]).is_equal(56)


func test_y_feeds_then_opens_dress_up() -> void:
	h.session.inventory.add(&"item_kibble", 2)
	var fed := [0]
	EventBus.pet_fed.connect(func(_i, _g): fed[0] += 1)
	await _pet_in_front()
	h.press("interact_alt_pressed")
	await h.frames(80)
	assert_int(fed[0]).is_equal(1)
	assert_int(h.session.pets.pet()["fed_day"]).is_equal(3)
	assert_int(h.session.pets.pet()["happiness"]).is_equal(70)
	await _pet_in_front()
	h.press("interact_alt_pressed")
	await h.frames(30)
	assert_str(h.menus.top().menu_id).is_equal(&"pet_wardrobe")
	h.menus.close_all()


func test_bowl_self_feed_at_rollover() -> void:
	h.session.inventory.add(&"item_piece_feed_bowl", 1)
	var uid: String = h.session.build.try_place(&"piece_feed_bowl", Vector3i(-10, 0, 16), 0).data
	h.session.storage.container(uid).add(&"item_kibble", 1)
	h.session.pets.pet()["fed_day"] = 2
	h.session.rollover.run(4)
	assert_int(h.session.pets.pet()["fed_day"]).is_equal(4)
	assert_int(h.session.storage.container(uid).count(&"item_kibble")).is_equal(0)


func _equip_check(species: StringName) -> void:
	h.session.inventory.add(&"item_petacc_bandana", 1)
	var slot := -1
	for i in h.session.inventory.model.slots.size():
		var s = h.session.inventory.model.slots[i]
		if s and s["item_id"] == &"item_petacc_bandana":
			slot = i
	assert_bool(h.session.pets.equip_accessory(slot).ok).is_true()
	var p: Pet = h.session.pets.node
	var att: BoneAttachment3D = p.attachments[&"NECK"]
	assert_str(att.bone_name).is_equal(String(Database.pet_species[species].accessory_bones["NECK"]))
	assert_object(p.accessory_mesh(&"NECK")).is_not_null()
	var d := h.session.to_dict()
	h.session.pets.from_dict(JSON.parse_string(JSON.stringify(d["pets"])))
	h.session.pets.spawn()
	await h.frames(2)
	assert_object(h.session.pets.node.accessory_mesh(&"NECK")).is_not_null()
	assert_bool(h.session.pets.remove_accessory(&"NECK").ok).is_true()
	await h.frames(1)
	assert_object(h.session.pets.node.accessory_mesh(&"NECK")).is_null()


func test_accessory_on_dog() -> void:
	await _equip_check(&"pet_dog")


func test_accessory_on_cat() -> void:
	h.session.pets.pets.clear()
	h.session.pets.node.queue_free()
	await h.frames(1)
	PetFixture.adopt(h, &"pet_cat")
	await _equip_check(&"pet_cat")
