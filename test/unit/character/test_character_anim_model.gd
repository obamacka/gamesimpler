# PA2.7: clip mapping (spec 11.7) and the merged clip library.
extends GdUnitTestSuite




func test_every_mapped_clip_exists_in_the_library() -> void:
	var lib := CharacterRig.library()
	assert_int(lib.get_animation_list().size()).is_greater_equal(80)
	for c in CharacterAnimModel.all_clips():
		assert_bool(lib.has_animation(c)).override_failure_message("missing clip %s" % c).is_true()


func test_loop_suffix_is_stripped_and_loops() -> void:
	var lib := CharacterRig.library()
	assert_bool(lib.has_animation(&"Idle_Loop")).is_false()
	assert_int(lib.get_animation(&"Idle").loop_mode).is_not_equal(Animation.LOOP_NONE)
	assert_int(lib.get_animation(&"Jump_Start").loop_mode).is_equal(Animation.LOOP_NONE)


func test_every_player_state_has_a_clip() -> void:
	for st in [PlayerTransitionTable.IDLE, PlayerTransitionTable.WALK, PlayerTransitionTable.RUN, PlayerTransitionTable.DUCK, PlayerTransitionTable.JUMP, PlayerTransitionTable.FALL, PlayerTransitionTable.MINE, PlayerTransitionTable.INTERACT, PlayerTransitionTable.SLEEP, PlayerTransitionTable.BUILD, PlayerTransitionTable.SIT, PlayerTransitionTable.CRAFT, PlayerTransitionTable.TALK, PlayerTransitionTable.EMOTE, PlayerTransitionTable.PLAY_INSTRUMENT]:
		var r := CharacterAnimModel.for_player(st)
		assert_str(String(r["clip"])).override_failure_message(String(st)).is_not_empty()


func test_state_details_pick_the_clip() -> void:
	assert_str(CharacterAnimModel.for_player(PlayerTransitionTable.DUCK, {"moving": true})["clip"]).is_equal(&"Crouch_Fwd")
	assert_str(CharacterAnimModel.for_player(PlayerTransitionTable.DUCK)["clip"]).is_equal(&"Crouch_Idle")
	assert_str(CharacterAnimModel.for_player(PlayerTransitionTable.MINE, {"tool": ToolTypes.WATERING_CAN})["clip"]).is_equal(&"Farm_Watering")
	assert_str(CharacterAnimModel.for_player(PlayerTransitionTable.MINE, {"tool": ToolTypes.PICKAXE})["clip"]).is_equal(&"TreeChopping")
	assert_str(CharacterAnimModel.for_player(PlayerTransitionTable.EMOTE, {"emote": &"emote_dance"})["clip"]).is_equal(&"Dance")
	assert_str(CharacterAnimModel.for_player(PlayerTransitionTable.INTERACT, {"interact": &"STORAGE"})["clip"]).is_equal(&"Chest_Open")
	assert_str(CharacterAnimModel.for_player(PlayerTransitionTable.BUILD, {"moving": true})["clip"]).is_equal(&"Walk")
	assert_str(CharacterAnimModel.for_player(PlayerTransitionTable.BUILD, {"working": true})["clip"]).is_equal(&"Fixing_Kneeling")
	var jump := CharacterAnimModel.for_player(PlayerTransitionTable.JUMP)
	assert_str(jump["clip"]).is_equal(&"Jump_Start")
	assert_str(jump["then"]).is_equal(&"Jump")
	assert_bool(CharacterAnimModel.for_player(PlayerTransitionTable.SLEEP)["hold"]).is_true()
	assert_str(CharacterAnimModel.for_player(PlayerTransitionTable.SIT)["then"]).is_equal(&"Sitting_Idle")


func test_every_emote_and_reaction_is_mapped() -> void:
	for id in Database.emotes:
		assert_bool(CharacterAnimModel.EMOTE_CLIPS.has(id)).override_failure_message(String(id)).is_true()
		var e: EmoteDef = Database.emotes[id]
		assert_bool(CharacterAnimModel.REACTION_CLIPS.has(e.npc_reaction)).override_failure_message(String(e.npc_reaction)).is_true()
	assert_str(CharacterAnimModel.for_npc(true, false, &"")["clip"]).is_equal(&"Walk")
	assert_str(CharacterAnimModel.for_npc(false, true, &"")["clip"]).is_equal(&"Idle_Talking")
	assert_str(CharacterAnimModel.for_npc(false, false, &"cheer")["clip"]).is_equal(&"Yes")
