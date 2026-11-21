## Folders of the Quaternius art used by world objects (spec 12.8).
class_name ArtPaths
extends RefCounted

const VILLAGE := "res://assets/third_party/quaternius/village/"
const PROPS := "res://assets/third_party/quaternius/props/"
const NATURE := "res://assets/third_party/quaternius/nature/"
const BUILDINGS := "res://scenes/art/buildings/"
const TREES := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5"]


static func tree(i: int) -> String:
	return NATURE + TREES[absi(i) % TREES.size()] + ".gltf"


## A fallen log (spec 12.8): a bark-textured cylinder lying along x.
static func log_mesh(length: float = 2.0, radius: float = 0.25) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = "Log"
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 14
	var mat := StandardMaterial3D.new()
	var tex := load(NATURE + "Bark_NormalTree.png") as Texture2D
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(2, 1, 1)
	else:
		mat.albedo_color = Color(0.4, 0.27, 0.15)
	c.material = mat
	m.mesh = c
	m.rotation.z = PI * 0.5
	m.position.y = radius
	return m
