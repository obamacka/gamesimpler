# P5.18: pet following on a straight-line path provider.
extends GdUnitTestSuite

var h: Phase2Harness
var pet: Pet
var _rec: SignalRecorder


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	PetFixture.setup(h)
	h.place(Vector3(-7.5, 0, 12.5))
	await h.frames(2)
	pet = PetFixture.adopt(h)
	await h.frames(4)
	_rec = SignalRecorder.new(EventBus, [&"pet_state_changed"])


func after_test() -> void:
	_rec.stop()
	h.stop()
	await get_tree().process_frame


func _flat_dist() -> float:
	var a := pet.global_position
	var b := h.player.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()


func _states() -> Array:
	return _rec.records.map(func(r): return r["args"][1])


func test_follow_keeps_follow_distance() -> void:
	h.place(Vector3(0.5, 0, 12.5))   # 8 m away
	await h.frames(180)
	assert_float(_flat_dist()).is_less(pet.species.follow_distance + 0.8)
	assert_float(_flat_dist()).is_greater(0.5)


func test_idle_then_wander_timings() -> void:
	await h.frames(140)   # player still: idle after 2 s (120 frames)
	assert_array(_states()).contains([PetBrainModel.IDLE])
	assert_bool(_states().has(PetBrainModel.WANDER)).is_false()
	await h.frames(260)   # wander after 6 s (360 frames)
	assert_array(_states()).contains([PetBrainModel.WANDER])


func test_teleport_when_far_and_on_zone_change() -> void:
	h.place(Vector3(-7.5, 0, -14.5))   # 27 m away
	await h.frames(4)
	assert_array(_states()).contains([PetBrainModel.TELEPORT])
	assert_float(_flat_dist()).is_less(4.0)
	await SceneRouter.travel(&"zone_wilderness", &"spawn_start")
	await h.frames(4)
	assert_bool(is_instance_valid(pet)).is_true()
	assert_float(_flat_dist()).is_less(4.0)


func test_never_blocks_the_player() -> void:
	assert_int(pet.collision_layer & h.player.collision_mask).is_equal(0)
	assert_int(h.player.collision_layer & pet.collision_mask).is_equal(0)


func test_nudged_off_a_new_piece() -> void:
	await h.frames(130)   # settle into idle beside the player
	var cell := IVoxelWorld.cell_of(pet.global_position + Vector3(0, 0.1, 0))
	assert_bool(h.session.housing.plot_at(&"zone_home_meadow", cell) != null).override_failure_message("pet left the plot").is_true()
	h.session.inventory.add(&"item_piece_chair", 1)
	assert_bool(h.session.build.try_place(&"piece_chair", cell, 0).ok).is_true()
	assert_vector(IVoxelWorld.cell_of(pet.global_position + Vector3(0, 0.1, 0))).is_not_equal(cell)


func test_pet_call() -> void:
	h.place(Vector3(-7.5, 0, 19.5))   # 7 m: within call range
	await h.frames(2)
	h.player.velocity = Vector3.ZERO
	pet.facts.clear()
	h.press("pet_call_pressed")
	await h.frames(3)
	assert_array(_states()).contains([PetBrainModel.CALL])
	await h.frames(150)
	assert_float(_flat_dist()).is_less(1.5)
	assert_array(_states()).contains([PetBrainModel.FOLLOW])
