## World visual for an item (spec 11.3): its `world_model` fitted into a cube of `size` standing
## on the origin, or a coloured box when the item has no model.
class_name ItemVisual
extends RefCounted

const MODEL_META := &"item_model"


static func make(item_id: StringName, size: float, fallback: Color) -> Node3D:
	var it: ItemDef = Database.items.get(item_id)
	var model := ModelFit.instantiate(it.world_model if it else "")
	if model == null:
		return WorldObject.box_mesh(Vector3.ONE * size, fallback, Vector3(0, size * 0.5, 0))
	var holder := Node3D.new()
	holder.set_meta(MODEL_META, it.world_model)
	holder.add_child(model)
	ModelFit.fit(model, AABB(Vector3(-size * 0.5, 0, -size * 0.5), Vector3.ONE * size), 0)
	return holder
