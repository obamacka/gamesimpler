## Dig commands, protection and voxel drops (spec 1.8, 4.3, 9.3).
class_name TerrainService
extends Node

var session: GameSession
var world: IVoxelWorld
var rules: TerrainRules
var dig := VoxelDigModel.new()
var chest_voxel := -1


func setup(s: GameSession, w: IVoxelWorld) -> void:
	session = s
	set_world(w)


## Rebinds the terrain (zones call this on load). Protection volumes are re-registered by the zone.
func set_world(w: IVoxelWorld) -> void:
	world = w
	rules = TerrainRules.new(w)
	rules.bedrock_voxel = _voxel_of_special(VoxelMaterialDef.SPECIAL_BEDROCK)
	chest_voxel = _voxel_of_special(VoxelMaterialDef.SPECIAL_CHEST)


func _voxel_of_special(special: StringName) -> int:
	for m in Database.materials.values():
		if m.special == special:
			return m.voxel_id
	return -1


func material_at(cell: Vector3i) -> VoxelMaterialDef:
	return Database.material_by_voxel(world.get_voxel(cell))


func can_dig(cell: Vector3i) -> StringName:
	return rules.can_dig(cell)


## One strike on `cell` with `tool`. Returns {"result": StringName, "hits_left": int}.
## result: a TerrainRules reason, VoxelDigModel.TIER_TOO_LOW / NOT_A_DIG_TOOL / DAMAGED / DUG.
func hit_voxel(cell: Vector3i, tool: ToolData) -> Dictionary:
	var reason := rules.can_dig(cell)
	if reason != TerrainRules.OK:
		return {"result": reason, "hits_left": 0}
	var mat := material_at(cell)
	if mat == null:
		return {"result": TerrainRules.EMPTY, "hits_left": 0}
	var r := dig.hit(cell, mat, tool)
	match r["result"]:
		VoxelDigModel.DAMAGED:
			EventBus.voxel_damaged.emit(cell, r["hits_left"])
		VoxelDigModel.DUG:
			world.set_voxel(cell, IVoxelWorld.AIR)
			var center := Vector3(cell) + Vector3(0.5, 0.5, 0.5)
			session.world_state.give_drops(LootRoller.roll(Database.loot_tables.get(mat.drop), session.rng), center)
			if mat.special == VoxelMaterialDef.SPECIAL_GEODE:
				EventBus.geode_found.emit(cell)
			var d := session.discovery.model.on_voxel_dug(mat, cell, world, chest_voxel)
			if d["extra_geode"]:
				session.world_state.give_drops([{"item": Database.discovery.geode_item_id, "qty": 1}], center)
				EventBus.geode_found.emit(cell)
			for c in d["chest_cells"]:
				session.world_state.spawn_chest(c, SceneRouter.current_zone_id)
			EventBus.voxel_dug.emit(cell, mat.id)
	return r


func daily_reset(_day: int) -> void:
	dig.daily_reset()
