## Phase 5 helpers: grass ground in the meadow fixture and a pet on a straight-line path
## provider (spec 9.4 FakePathProvider).
class_name PetFixture
extends RefCounted


static func setup(h: Phase2Harness) -> void:
	h.world.fill(Vector3i(-30, -1, -30), Vector3i(30, -1, 30), h.vid(&"mat_grass"))
	h.session.housing.grant_deed(&"plot_test")


static func adopt(h: Phase2Harness, species: StringName = &"pet_dog") -> Pet:
	h.session.pets.path_override = PetPathProvider.new()
	h.session.pets.adopt(species, 0, "Biscuit")
	return h.session.pets.node


static func npc(h: Phase2Harness, id: StringName, pos: Vector3) -> Npc:
	var n := Npc.new()
	n.npc_id = id
	n.name = String(id)
	h.add_scene_node(n, pos)
	return n
