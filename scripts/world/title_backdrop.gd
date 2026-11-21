## Title screen backdrop (spec 12.1): a small meadow vista with a KayKit house, trees, the
## player character and the dog; the camera slowly circles (still with reduce_motion).
class_name TitleBackdrop
extends Node3D

const HEX := "res://assets/third_party/kaykit/hexagon/"
const ORBIT_SPEED := 0.06   # radians per second

var camera: Camera3D
var character: CharacterRig
var _angle := 0.4


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var mat := StandardMaterial3D.new()
	var grass := grass_top()
	if grass:
		mat.albedo_texture = grass
		mat.uv1_scale = Vector3(30, 30, 1)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	else:
		mat.albedo_color = Color(0.42, 0.66, 0.31)
	ground.material_override = mat
	add_child(ground)
	_prop(HEX + "building_home_A_blue.gltf", Vector3(-3.2, 0, -2.0), Vector3(5, 6, 5), 20)
	_prop(HEX + "tree_single_A.gltf", Vector3(2.8, 0, -3.0), Vector3(2.4, 5, 2.4), 0)
	_prop(HEX + "tree_single_B.gltf", Vector3(4.6, 0, -0.5), Vector3(2.0, 4, 2.0), 40)
	_prop(HEX + "building_windmill_yellow.gltf", Vector3(9, 0, -9), Vector3(6, 9, 6), -30)
	_prop(HEX + "rock_single_A.gltf", Vector3(1.6, 0, 1.4), Vector3(0.9, 0.4, 0.9), 0)
	_prop(HEX + "fence_wood_straight.gltf", Vector3(-0.5, 0, 2.6), Vector3(3, 1, 0.4), 0)
	character = CharacterRig.new()
	add_child(character)
	character.setup(&"FEMALE", "Hair_SimpleParted")
	character.rotation.y = 0.3
	character.position = Vector3(0.3, 0, 0.3)
	character.play({"clip": &"Interact", "then": CharacterAnimModel.IDLE})
	if Database.pet_species.has(&"pet_dog"):
		var dog := Pet.create(null, {"species_id": "pet_dog", "color_variant": 0, "accessories": {}})
		dog.set_physics_process(false)
		add_child(dog)
		dog.position = Vector3(1.3, 0, 0.9)
		(dog.get_node("Visual") as Node3D).rotation.y = -0.6
	camera = Camera3D.new()
	camera.fov = 50
	add_child(camera)
	camera.current = true
	_place_camera()


## The recoloured grass top tile (first third of the grass block atlas).
static func grass_top() -> Texture2D:
	if not Database.materials.has(&"mat_grass"):
		return null
	var atlas := VoxelLibraryBuilder.atlas_for(Database.materials[&"mat_grass"])
	if atlas == null:
		return null
	var img := atlas.get_image()
	var top := img.get_region(Rect2i(0, 0, img.get_width() / VoxelLibraryBuilder.ATLAS.x, img.get_height()))
	top.generate_mipmaps()
	return ImageTexture.create_from_image(top)


func _prop(path: String, pos: Vector3, size: Vector3, yaw_deg: float) -> void:
	var m := ModelFit.instantiate(path)
	if m == null:
		return
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = deg_to_rad(yaw_deg)
	add_child(holder)
	holder.add_child(m)
	ModelFit.fit(m, AABB(Vector3(-size.x * 0.5, 0, -size.z * 0.5), size), 0)


func _process(delta: float) -> void:
	if not Accessibility.reduce_motion():
		_angle += ORBIT_SPEED * delta
	_place_camera()


func _place_camera() -> void:
	var center := Vector3(0.5, 1.1, 0)
	var pos := center + Vector3(sin(_angle) * 7.5, 1.6, cos(_angle) * 7.5)
	camera.look_at_from_position(pos, center + Vector3(0, -0.1, 0))
