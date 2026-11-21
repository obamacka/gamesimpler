## Non-interactive scenery (spec 12.3): a model fitted into `size` (standing on the node's
## origin), turned by `yaw_deg`, with an optional box collider of the fitted size. The voxel
## under it is protected so digging cannot leave it floating.
class_name DecorProp
extends WorldObject

const HEX := "res://assets/third_party/kaykit/hexagon/"

@export_file("*.gltf", "*.glb", "*.fbx") var model := ""
@export var size := Vector3(1, 1, 1)
@export var yaw_deg := 0
@export var solid := true
## Furniture: show at the KayKit world scale (spec 11.4) instead of fitting into `size`.
@export var use_world_scale := false

var art: Node3D


func _ready() -> void:
	if use_world_scale:
		var m := ModelFit.instantiate(model)
		if m:
			art = Node3D.new()
			art.name = "Art"
			add_child(art)
			art.add_child(m)
			ModelFit.place(m, AABB(), yaw_deg)
	else:
		art = add_art(self, model, AABB(Vector3(-size.x * 0.5, 0, -size.z * 0.5), size), yaw_deg)
	if art and solid:
		var b := art_bounds(art)
		add_static_box(self, b.size, b.get_center())
	var s := session()
	if s and s.terrain and s.terrain.rules:
		s.terrain.rules.protect_support(base_cell(), "decor:%s/%s" % [SceneRouter.current_zone_id, name])
