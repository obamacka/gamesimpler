## Physics-frame waits for integration tests. gdUnit4's simulate_frames() awaits
## process frames only, so Area3D overlaps and CharacterBody3D motion must be
## advanced with real physics frames (spec 0.3, 8.2 item 6).
class_name PhysicsWait
extends RefCounted


## Awaits `count` physics frames on `tree`. Usage: await PhysicsWait.frames(get_tree(), 12)
static func frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.physics_frame
