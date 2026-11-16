## Pet path seam (spec 9.4, P5.7). find_path returns world points to walk through, or [] when
## there is no path. The base class walks straight (used where the ground is known flat).
class_name PetPathProvider
extends RefCounted

var fail := false   # tests: simulate "no path"


func find_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	if fail:
		return []
	return [to]
