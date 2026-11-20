## Phase 3 fixture on top of Phase2Harness: zone_home_meadow fixture, grass on dirt at y -1,
## the test plot (x -12..-3, z 10..19) granted, hammer and screwdriver owned.
class_name BuildFixture
extends RefCounted


static func setup(h: Phase2Harness) -> void:
	h.world.fill(Vector3i(-16, -3, 4), Vector3i(2, -2, 24), h.vid(&"mat_dirt"))
	h.world.fill(Vector3i(-16, -1, 4), Vector3i(2, -1, 24), h.vid(&"mat_grass"))
	h.session.housing.grant_deed(&"plot_test")
	for t in [&"item_hammer_basic", &"item_screwdriver_basic"]:
		h.session.toolbelt.model.grant(t)
	GameClock.model.set_time(3, 9 * 60)


## Aims from the eyes at a point (e.g. a fastener socket).
static func aim_at_point(h: Phase2Harness, p: Vector3) -> void:
	var eye := h.player.global_position + Vector3(0, h.player.config.eye_height_standing, 0)
	h.player.tool_selector.set_aim_for_tests(eye, p - eye)


## Aims at the center of a voxel's top face.
static func aim_at_top(h: Phase2Harness, cell: Vector3i) -> void:
	aim_at_point(h, Vector3(cell) + Vector3(0.5, 0.98, 0.5))


static func enter_build(h: Phase2Harness) -> void:
	h.press("build_toggle_pressed")
	await h.frames(3)


static func place_fastened(h: Phase2Harness, piece_id: StringName, cell: Vector3i, rot: int) -> String:
	var def: BuildPieceDef = Database.pieces[piece_id]
	h.session.inventory.add(def.item_id, 1)
	var uid: String = h.session.build.try_place(piece_id, cell, rot).data
	if def.needs_fastening():
		var need := 1 if def.fastener == BuildPieceDef.SCREWS else def.hits_per_socket
		for i in def.fastener_sockets.size():
			for k in need:
				h.session.build.fasten_step(uid, i)
	return uid
