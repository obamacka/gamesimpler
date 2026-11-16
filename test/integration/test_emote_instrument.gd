# P5.22: wheel -> Emote with pet and NPC reactions; instrument mode notes.
extends GdUnitTestSuite

var h: Phase2Harness
var pet: Pet
var npc: Npc


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	PetFixture.setup(h)
	GameClock.model.set_time(3, 9 * 60)
	h.place(Vector3(-7.5, 0, 12.5))
	await h.frames(2)
	pet = PetFixture.adopt(h)
	npc = PetFixture.npc(h, &"npc_neighbor", Vector3(-4.5, 0, 12.5))
	await h.frames(4)


func after_test() -> void:
	h.stop()
	await get_tree().process_frame


func _open_wheel() -> MenuBase:
	h.press("wheel_pressed")
	await h.frames(2)
	return h.menus.top()


func test_wave_reactions() -> void:
	var states: Array = []
	EventBus.pet_state_changed.connect(func(_a, b): states.append(b))
	var w := await _open_wheel()
	assert_str(w.menu_id).is_equal(&"wheel")
	assert_bool(get_tree().paused).is_true()
	w.commit_slot(w.entries.find(&"emote_wave"))
	await h.frames(4)
	assert_str(h.player.machine.current_id).is_equal(&"emote")
	assert_bool(states.has(PetBrainModel.REACT)).is_true()
	assert_str(npc.last_reaction).is_equal(&"wave")
	assert_int(h.session.npcs.model.of(&"npc_neighbor")["friendship"]).is_equal(1)
	await h.frames(100)   # wave lasts 1.5 s
	assert_str(h.player.machine.current_id).is_equal(&"idle")


func test_far_npc_does_not_react() -> void:
	npc.global_position = Vector3(-7.5, 0, 19.0)   # 6.5 m
	await h.frames(2)
	var w := await _open_wheel()
	w.commit_slot(w.entries.find(&"emote_dance"))
	await h.frames(4)
	assert_str(npc.last_reaction).is_equal(&"")


func test_instrument_notes_and_exit_on_move() -> void:
	var notes: Array = []
	EventBus.note_played.connect(func(_i, n): notes.append(n))
	var w := await _open_wheel()
	w.set_page(1)
	w.commit_slot(w.entries.find(&"inst_flute"))
	await h.frames(3)
	assert_str(h.player.machine.current_id).is_equal(&"playinstrument")
	for i in 8:
		h.press("jump_pressed", {"notes_pressed": 1 << i})   # A is also note 1: it must not jump
		await h.frames(1)
	assert_array(notes).is_equal([0, 1, 2, 3, 4, 5, 6, 7])
	assert_str(h.player.machine.current_id).is_equal(&"playinstrument")
	h.hold({"move": Vector2(1, 0)})
	await h.frames(2)
	h.hold({})
	assert_str(h.player.machine.current_id).is_not_equal(&"playinstrument")


func test_tool_page_is_manual_override() -> void:
	var w := await _open_wheel()
	w.set_page(2)
	w.commit_slot(w.entries.find(ToolTypes.HOE))
	await h.frames(2)
	assert_str(h.session.toolbelt.model.equipped).is_equal(ToolTypes.HOE)
