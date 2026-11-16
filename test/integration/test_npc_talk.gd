# P5.21: Talk locks the NPC and pauses for dialogue; Y gift once per day.
extends GdUnitTestSuite

var h: Phase2Harness
var npc: Npc


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	PetFixture.setup(h)
	GameClock.model.set_time(3, 9 * 60)
	h.place(Vector3(-7.5, 0, 12.5))
	h.player.face_towards(Vector3(-7.5, 0, 10.0))
	npc = PetFixture.npc(h, &"npc_hilde", Vector3(-7.5, 0, 11.2))
	await h.frames(4)


func after_test() -> void:
	h.stop()
	await get_tree().process_frame


func test_talk_locks_npc_and_returns_to_idle() -> void:
	h.press("interact_pressed")
	var n := 0
	while not h.menus.is_open() and n < 60:
		await h.frames(1)
		n += 1
	assert_str(h.player.machine.current_id).is_equal(&"talk")
	assert_str(h.menus.top().menu_id).is_equal(&"dialogue")
	assert_bool(get_tree().paused).is_true()
	assert_bool(npc.talking).is_true()
	assert_object(h.player.camera_rig.two_shot_target).is_same(npc)
	var rig := h.player.camera_rig
	assert_float(absf(angle_difference(rig.yaw, rig.two_shot_yaw(h.player.global_position)))).is_less(0.1)   # blended before the menu
	assert_bool(h.session.npcs.model.of(&"npc_hilde")["met"]).is_true()
	var d: MenuBase = h.menus.top()
	d.advance()
	d.choose(DialogueModel.END)
	await h.frames(4)
	assert_str(h.player.machine.current_id).is_equal(&"idle")
	assert_bool(npc.talking).is_false()
	assert_object(h.player.camera_rig.two_shot_target).is_null()


func test_gift_once_per_day_by_preference() -> void:
	h.session.inventory.add(&"item_berry_tart", 1)
	h.session.inventory.add(&"item_apple", 1)
	h.press("interact_alt_pressed")
	await h.frames(30)
	assert_str(h.menus.top().menu_id).is_equal(&"gift_picker")
	assert_bool(h.menus.top().give(&"item_berry_tart").ok).is_true()
	await h.frames(4)
	assert_int(h.session.npcs.model.of(&"npc_hilde")["friendship"]).is_equal(80)
	assert_int(h.session.inventory.count(&"item_berry_tart")).is_equal(0)
	h.press("interact_alt_pressed")
	await h.frames(30)
	var g: MenuBase = h.menus.top()
	assert_str(g.give(&"item_apple").error).is_equal(NpcModel.ALREADY_GIFTED)
	assert_int(h.session.inventory.count(&"item_apple")).is_equal(1)
	h.menus.close_all()
