## Baked navigation for NPCs and the pet (spec 9.4). Source geometry: static colliders under
## the zone (floors, walls, counters on layers world and build_pieces) plus the top faces of
## voxel columns inside `region`. Overworld zones bake only their protected town volumes;
## STATIC zones bake their bounds. Baking happens once the zone's ground is ready.
class_name ZoneNavigation
extends NavigationRegion3D

const AGENT_RADIUS := 0.5   # a multiple of the 0.25 m cell size (Recast ceils otherwise)
const AGENT_HEIGHT := 2.0

var region := AABB()
var baked := false


func bake_now(zone: Node3D, world: IVoxelWorld, aabb: AABB) -> int:
	region = aabb
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1 | 64
	nm.agent_radius = AGENT_RADIUS
	nm.agent_height = AGENT_HEIGHT
	nm.agent_max_climb = 0.5
	nm.filter_baking_aabb = aabb
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, zone)
	if world:
		var faces := voxel_top_faces(world, aabb)
		if not faces.is_empty():
			src.add_faces(faces, Transform3D())
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	navigation_mesh = nm
	baked = true
	EventBus.navigation_baked.emit(nm.get_polygon_count())
	return nm.get_polygon_count()


## One upward quad per column: the highest solid voxel with air above, inside `aabb`.
static func voxel_top_faces(world: IVoxelWorld, aabb: AABB) -> PackedVector3Array:
	var out := PackedVector3Array()
	var lo := Vector3i(floori(aabb.position.x), floori(aabb.position.y), floori(aabb.position.z))
	var hi := Vector3i(floori(aabb.end.x), floori(aabb.end.y), floori(aabb.end.z))
	for x in range(lo.x, hi.x):
		for z in range(lo.z, hi.z):
			for y in range(hi.y, lo.y - 1, -1):
				if world.get_voxel(Vector3i(x, y, z)) != IVoxelWorld.AIR:
					if world.get_voxel(Vector3i(x, y + 1, z)) == IVoxelWorld.AIR:
						var t := float(y + 1)
						# Winding as Godot's source geometry expects for walkable (upward) faces.
						out.append_array([Vector3(x, t, z), Vector3(x + 1, t, z), Vector3(x + 1, t, z + 1),
							Vector3(x, t, z), Vector3(x + 1, t, z + 1), Vector3(x, t, z + 1)])
					break
	return out
