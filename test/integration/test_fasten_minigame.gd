# P3.18: nails and screws (spec 2.7). The player stands 2.5 m in front of the piece.
extends GdUnitTestSuite

const WALL := Vector3i(-8, 0, 15)
const SHELF := Vector3i(-6, 0, 15)

var h: Phase2Harness
var _rec: SignalRecorder


func before_test() -> void:
	h = Phase2Harness.new(self)
	await h.start(&"zone_home_meadow", &"spawn_start")
	BuildFixture.setup(h)
	_rec = SignalRecorder.new(EventBus, [&"piece_fastened", &"fasten_progressed", &"tool_auto_selected"])


func after_test() -> void:
	_rec.stop()
	h.stop()
	await get_tree().process_frame


func _socket(uid: String, i: int) -> Vector3:
	var inst: Dictionary = h.session.build.pieces[uid]
	return BuildGrid.world_point(inst["cell"], inst["rot"], h.session.build.def_of(uid).fastener_sockets[i])


func _setup_piece(item: StringName, piece: StringName, cell: Vector3i, stand: Vector3) -> String:
	h.session.inventory.add(item, 1)
	var uid: String = h.session.build.try_place(piece, cell, 0).data
	h.place(stand)
	h.aim_at_sky()
	await h.frames(3)
	await BuildFixture.enter_build(h)
	BuildFixture.aim_at_point(h, _socket(uid, 0))
	await h.frames(16)   # auto-tool debounce
	return uid


func test_nails_by_presses_with_auto_advance() -> void:
	var uid := await _setup_piece(&"item_piece_wall", &"piece_wall", WALL, Vector3(-7.5, 0, 13))
	assert_str(h.session.toolbelt.model.equipped).is_equal(ToolTypes.HAMMER)
	var stamina := h.session.stamina.model.current
	var order: Array = []
	for i in 8:
		order.append(h.player.build_ctl.reticle_socket())
		h.press("use_pressed")
		await h.frames(2)
		if i == 0:
			assert_str(h.player.build_ctl.model.sub).is_equal(BuildModel.FASTEN)
	assert_array(order).is_equal([0, 0, 1, 1, 3, 3, 2, 2])
	assert_int(_rec.count(&"piece_fastened")).is_equal(1)
	assert_str(h.session.build.pieces[uid]["state"]).is_equal(BuildService.FASTENED)
	assert_int(h.session.stamina.model.current).is_equal(stamina - 8)   # hammer hit 1 (spec 6.1)
	assert_str(h.player.build_ctl.model.sub).is_equal(BuildModel.PREVIEW)
	h.session.inventory.add(&"item_piece_roof", 1)
	assert_bool(h.session.build.validate(&"piece_roof", WALL + Vector3i(0, 3, 0), 0)["ok"]).is_true()   # now supports


func test_screws_by_holding() -> void:
	var uid := await _setup_piece(&"item_piece_shelf", &"piece_shelf", SHELF, Vector3(-5.5, 0, 13))
	assert_str(h.session.toolbelt.model.equipped).is_equal(ToolTypes.SCREWDRIVER)
	h.press("use_pressed", {"use_held": true})
	h.hold({"use_held": true})
	await h.frames(30)
	h.hold({})
	await h.frames(2)
	assert_str(h.player.build_ctl.model.sub).is_equal(BuildModel.FASTEN)
	assert_int(_rec.count(&"fasten_progressed")).is_equal(0)   # released at 0.5 s: partial, kept
	h.hold({"use_held": true})
	await h.frames(120)
	h.hold({})
	assert_int(_rec.count(&"piece_fastened")).is_equal(1)
	assert_str(h.session.build.pieces[uid]["state"]).is_equal(BuildService.FASTENED)


func test_b_cancels_with_progress_kept() -> void:
	var uid := await _setup_piece(&"item_piece_wall", &"piece_wall", WALL, Vector3(-7.5, 0, 13))
	h.press("use_pressed")
	await h.frames(2)
	assert_str(h.player.build_ctl.model.sub).is_equal(BuildModel.FASTEN)
	h.press("duck_pressed")
	await h.frames(2)
	assert_str(h.player.build_ctl.model.sub).is_equal(BuildModel.PREVIEW)
	assert_str(h.player.machine.current_id).is_equal(&"build")   # B in Fasten cancels, does not exit
	assert_array(h.session.build.pieces[uid]["fasten"]).is_equal([1, 0, 0, 0])
	assert_int(_rec.count(&"piece_fastened")).is_equal(0)
	await h.frames(2)
	h.press("use_pressed")   # resumes on the same socket
	await h.frames(2)
	assert_array(h.session.build.pieces[uid]["fasten"]).is_equal([2, 0, 0, 0])
