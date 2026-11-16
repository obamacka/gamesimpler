# P2.30: Suite B (spec 8.4) cases B1 to B11 and B14 to B17. B12 (autosave content) is in
# Phase 6, B13 (contract deadline) in Phase 4. Day 5, 14:00; home is the starter cabin fixture.
extends GdUnitTestSuite

const ORDER_SIGNALS: Array[StringName] = [&"stamina_depleted", &"player_state_changed", &"sleep_transition_started",
	&"game_paused", &"mail_delivered", &"day_started", &"player_woke", &"game_resumed", &"zone_loaded"]

var h: Phase2Harness
var _rec: SignalRecorder


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start()
	h.world.fill(Vector3i(-10, -1, -10), Vector3i(10, -1, 10), h.vid(&"mat_dirt"))
	h.world.fill(Vector3i(3, -1, -1), Vector3i(4, -1, 1), h.vid(&"mat_stone"))
	h.session.inventory.add(&"item_wood", 3)
	h.session.inventory.add(&"item_apple", 2)
	h.session.wallet.model.coins = 500
	_rec = SignalRecorder.new(EventBus, ORDER_SIGNALS)


func after_test() -> void:
	_rec.stop()
	h.stop()
	await get_tree().process_frame


func _await_woke(timeout_frames: int = 600) -> void:
	var n := 0
	while _rec.count(&"player_woke") == 0 and n < timeout_frames:
		await get_tree().process_frame
		n += 1
	await h.frames(2)


## Digs the dirt voxel in front of the player with the shovel until stamina runs out.
func _exhaust_by_digging(stamina: int) -> void:
	h.session.stamina.model.current = stamina
	h.place(Vector3(0.5, 0, 0.5))
	h.aim_at_cell(Vector3i(0, -1, 2))
	await h.frames(12)
	h.press("use_pressed", {"use_held": true})
	h.hold({"use_held": true})


func test_b1_edge_triggered_depletion() -> void:
	h.session.stamina.model.current = 1
	assert_int(h.session.stamina.spend(2, &"dig")).is_equal(1)
	assert_int(h.session.stamina.model.current).is_equal(0)
	assert_int(_rec.count(&"stamina_depleted")).is_equal(1)
	h.session.stamina.spend(2, &"dig")
	assert_int(_rec.count(&"stamina_depleted")).is_equal(1)
	h.session.stamina.exhaustion_pending = false   # this case checks the edge only; do not start a sleep


func test_b2_last_action_lands_then_sleep() -> void:
	var dug: Array = []
	EventBus.voxel_dug.connect(func(c, _m): dug.append(c))
	await _exhaust_by_digging(2)   # dirt: 2 hits, 1 stamina each
	await _await_woke()
	assert_array(dug).contains([Vector3i(0, -1, 2)])
	assert_int(h.world.get_voxel(Vector3i(0, -1, 2))).is_equal(0)
	assert_int(h.session.inventory.count(&"item_dirt")).is_equal(1)
	var states := _rec.records.filter(func(r): return r["name"] == &"player_state_changed").map(func(r): return r["args"][1])
	assert_bool(states.has(&"sleep")).is_true()


func test_b3_signal_order() -> void:
	await _exhaust_by_digging(2)
	await _await_woke()
	var names: Array = []
	for r in _rec.records:
		if r["name"] == &"player_state_changed" and r["args"][1] != &"sleep":
			continue
		if r["name"] == &"zone_loaded":
			continue
		names.append(r["name"])
	assert_array(names).contains_exactly([&"stamina_depleted", &"player_state_changed", &"sleep_transition_started",
		&"game_paused", &"mail_delivered", &"day_started", &"player_woke", &"game_resumed"])
	var woke: Dictionary = _rec.records.filter(func(r): return r["name"] == &"player_woke")[0]
	assert_array(woke["args"]).contains_exactly([&"exhausted", 6])


func test_b4_wake_state() -> void:
	await _exhaust_by_digging(2)
	await _await_woke()
	assert_int(GameClock.model.day).is_equal(6)
	assert_int(GameClock.model.minute).is_equal(360)
	assert_str(SceneRouter.current_zone_id).is_equal(&"zone_starter_cabin")
	var bed := SceneRouter.find_marker(&"bed_01")
	assert_float(Vector2(h.player.global_position.x, h.player.global_position.z).distance_to(Vector2(bed.global_position.x, bed.global_position.z))).is_less(0.1)
	assert_int(h.session.stamina.model.current).is_equal(h.session.stamina.model.max_value())
	assert_str(h.player.machine.current_id).is_equal(&"idle")
	assert_bool(PauseManager.is_paused()).is_false()
	assert_array(PauseManager.reasons()).is_empty()
	assert_bool(h.session.stamina.exhaustion_pending).is_false()


func _care_letters() -> Array:
	return h.session.mail.model.inbox.filter(func(m): return m["kind"] == "CARE_PACKAGE")


func test_b5_care_letter_with_snack() -> void:
	await _exhaust_by_digging(2)
	await _await_woke()
	var letters := _care_letters()
	assert_int(letters.size()).is_equal(1)
	var m: Dictionary = letters[0]
	assert_int(m["deliver_day"]).is_equal(6)
	assert_str(m["sender_id"]).is_equal("npc_neighbor")
	assert_int(m["expires_day"]).is_equal(0)
	assert_bool(m["claimed"]).is_false()
	var items: Array = m["attachments"].filter(func(a): return a["type"] == "item")
	assert_int(items.size()).is_equal(1)
	assert_int(items[0]["qty"]).is_equal(1)
	assert_bool(Database.item(StringName(items[0]["item_id"])).tags.has(&"snack")).is_true()
	assert_int(h.session.exhaustion["last_snack_day"]).is_equal(6)


func test_b6_claim() -> void:
	await _exhaust_by_digging(2)
	await _await_woke()
	var m: Dictionary = _care_letters()[0]
	var snack := StringName(m["attachments"][0]["item_id"])
	assert_bool(h.session.mail.claim(m["id"]).ok).is_true()
	assert_int(h.session.inventory.count(snack)).is_equal(1)
	assert_str(h.session.mail.claim(m["id"]).error).is_equal(&"already_claimed")
	assert_int(h.session.inventory.count(snack)).is_equal(1)


func test_b7_repeat_same_day_no_snack() -> void:
	await _exhaust_by_digging(2)
	await _await_woke()
	_rec.clear()
	h.session.stamina.spend(1000, &"test")   # collapse again on day 6
	await _await_woke()
	assert_int(GameClock.model.day).is_equal(7)
	var letters := _care_letters()
	assert_int(letters.size()).is_equal(2)
	var second: Dictionary = letters[1]
	assert_array(second["attachments"].filter(func(a): return a["type"] == "item")).is_empty()


func test_b8_no_loss() -> void:
	var before_inv := h.session.inventory.model.to_dict()
	var before_belt := h.session.toolbelt.model.owned.duplicate()
	h.session.stamina.spend(1000, &"test")
	await _await_woke()
	assert_dict(h.session.inventory.model.to_dict()).is_equal(before_inv)
	assert_int(h.session.wallet.model.coins).is_equal(500)
	assert_dict(h.session.toolbelt.model.owned).is_equal(before_belt)


func test_b9_deferred_during_transition() -> void:
	SceneRouter.travel(&"zone_deep_mine", &"spawn_entry")   # not awaited
	h.session.stamina.spend(1000, &"test")
	await _await_woke()
	var names := _rec.names()
	assert_int(_rec.count(&"sleep_transition_started")).is_equal(1)
	assert_int(names.find(&"zone_loaded")).is_less(names.find(&"sleep_transition_started"))


func test_b10_duplicate_begin_sleep_ignored() -> void:
	h.session.sleep.begin_sleep(&"exhausted")
	h.session.sleep.begin_sleep(&"exhausted")
	await _await_woke()
	assert_int(_rec.count(&"sleep_transition_started")).is_equal(1)
	assert_int(_care_letters().size()).is_equal(1)


func test_b11_owned_home_bed() -> void:
	h.session.housing.set_home_bed(&"zone_wilderness", &"bed_plot")
	h.session.stamina.spend(1000, &"test")
	await _await_woke()
	assert_str(SceneRouter.current_zone_id).is_equal(&"zone_wilderness")
	assert_float(Vector2(h.player.global_position.x, h.player.global_position.z).distance_to(Vector2(20, 20))).is_less(0.1)


func test_b14_depletion_while_airborne_waits_for_landing() -> void:
	h.session.stamina.model.current = 1
	h.place(Vector3(0.5, 0, 0.5))
	h.aim_at_cell(Vector3i(0, -1, 2))
	await h.frames(12)
	h.press("jump_pressed")
	await h.frames(6)
	h.press("use_pressed")   # air dig, 1 stamina
	await h.frames(2)
	assert_int(_rec.count(&"stamina_depleted")).is_equal(1)
	assert_bool(h.player.current_state().is_airborne()).is_true()
	assert_int(_rec.count(&"sleep_transition_started")).is_equal(0)
	await _await_woke()
	assert_int(_rec.count(&"sleep_transition_started")).is_equal(1)


func test_b15_partial_damage_resets() -> void:
	h.session.terrain.hit_voxel(Vector3i(3, -1, 0), h.session.toolbelt.model.tool_data(ToolTypes.PICKAXE))
	assert_bool(h.session.terrain.dig.damage.has(Vector3i(3, -1, 0))).is_true()
	h.session.stamina.spend(1000, &"test")
	await _await_woke()
	assert_bool(h.session.terrain.dig.damage.is_empty()).is_true()
	assert_int(h.world.get_voxel(Vector3i(3, -1, 0))).is_equal(h.vid(&"mat_stone"))


func test_b16_deep_mine_wake() -> void:
	await SceneRouter.travel(&"zone_deep_mine", &"spawn_entry")
	h.session.world_state.spawn_chest(Vector3i(1, 0, 1), &"zone_deep_mine")
	h.session.stamina.spend(1000, &"test")
	await _await_woke()
	assert_str(SceneRouter.current_zone_id).is_equal(&"zone_starter_cabin")
	assert_dict(h.session.world_state.chests).is_empty()   # D16: Deep Mine chests reset daily


func test_b17_go_home_is_not_exhaustion() -> void:
	var sent := [0]
	EventBus.player_sent_home.connect(func(): sent[0] += 1)
	h.session.stamina.model.current = 40
	await h.session.sleep.go_home()
	assert_int(sent[0]).is_equal(1)
	assert_int(GameClock.model.day).is_equal(5)
	assert_array(_care_letters()).is_empty()
	assert_int(h.session.stamina.model.current).is_equal(40)
	assert_str(SceneRouter.current_zone_id).is_equal(&"zone_starter_cabin")
