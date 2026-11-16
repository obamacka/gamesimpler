## Pet pathing in STATIC zones (spec 9.4): NavigationServer3D on the world's map. Zones
## without a baked region (the small flat cabin) fall back to a straight line.
class_name NavmeshPathProvider
extends PetPathProvider

var map: RID


func _init(navigation_map: RID) -> void:
	map = navigation_map


func find_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	if fail:
		return []
	if NavigationServer3D.map_get_regions(map).is_empty():
		return [to]
	var p := NavigationServer3D.map_get_path(map, from, to, true)
	var out: Array[Vector3] = []
	for v in p:
		out.append(v)
	return out
