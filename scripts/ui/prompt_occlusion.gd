## Line-of-sight check for world prompts (spec 2.8): a prompt is hidden when solid geometry
## (physics bodies on world/build_pieces, or a voxel other than the target cell) lies between
## the camera and the target. Hits within `slack` of the target count as the target itself.
class_name PromptOcclusion
extends RefCounted

const MASK := 1 | 64


static func is_visible(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID],
		world: IVoxelWorld = null, target_cell = null, slack: float = 0.6) -> bool:
	var dist := from.distance_to(to)
	if dist < 0.01:
		return true
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK, exclude)
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and from.distance_to(hit["position"]) < dist - slack:
		return false
	if world:
		var v := world.raycast(from, to - from, dist)
		if not v.is_empty() and v["distance"] < dist - slack and (target_cell == null or v["cell"] != target_cell):
			return false
	return true
