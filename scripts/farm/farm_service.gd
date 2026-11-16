## Farming commands and events (spec 1.8, 10). Rules live in FarmModel; this service talks to
## terrain, inventory, stamina and the EventBus. Signals about crops carry the crop cell
## (soil + UP); soil_tilled carries the soil cell.
class_name FarmService
extends Node

const FARMLAND := &"mat_farmland"
const SPRINKLER_ITEM := &"item_sprinkler"
const NO_STAMINA := &"no_stamina"
const NO_SEED := &"no_seed"
const NOT_A_SEED := &"not_a_seed"
const MISSING_TOOL := &"missing_tool"
const NO_SPRINKLER := &"no_sprinkler"

var model := FarmModel.new()
var session: GameSession


func setup(s: GameSession) -> void:
	session = s
	if Database.farm:
		model.configure(Database.farm)


func _ready() -> void:
	EventBus.voxel_dug.connect(_on_voxel_dug)


func _exit_tree() -> void:
	if EventBus.voxel_dug.is_connected(_on_voxel_dug):
		EventBus.voxel_dug.disconnect(_on_voxel_dug)


func zone() -> StringName:
	return SceneRouter.current_zone_id


func _z(z: StringName) -> StringName:
	return z if z != &"" else zone()


func _rules() -> TerrainRules:
	return session.terrain.rules


func _world() -> IVoxelWorld:
	return session.terrain.world


func owned_plot_at(z: StringName, cell: Vector3i) -> PlotDef:
	return session.housing.plot_at(z, cell)


func _cell_free(cell: Vector3i) -> bool:
	return _world().get_voxel(cell) == IVoxelWorld.AIR and not _rules().occupied_cells.has(cell)


func farmable_reason(soil: Vector3i, z: StringName = &"") -> StringName:
	z = _z(z)
	var mat := session.terrain.material_at(soil)
	var free := 0
	for i in [1, 2]:
		if _cell_free(soil + Vector3i(0, i, 0)):
			free += 1
		else:
			break
	return FarmModel.farmable_reason(mat.id if mat else &"", free, owned_plot_at(z, soil) != null,
		_rules().can_dig(soil) == TerrainRules.PROTECTED)


## Tills farmable soil (stamina `till_stamina`), then plants `seed_item` if given (spec 10.4).
func try_till(soil: Vector3i, seed_item: StringName = &"", z: StringName = &"") -> Result:
	z = _z(z)
	if model.is_tilled(z, soil):
		return try_plant(soil, seed_item, z) if seed_item != &"" else Result.failure(&"already_tilled")
	var reason := farmable_reason(soil, z)
	if reason != &"":
		return Result.failure(reason)
	if not session.stamina.can_act():
		return Result.failure(NO_STAMINA)
	_world().set_voxel(soil, Database.voxel_id_of(FARMLAND))
	session.terrain.dig.damage.erase(soil)
	model.mark_tilled(z, soil)
	session.stamina.spend(Database.farm.till_stamina, &"till")
	EventBus.soil_tilled.emit(soil)
	if seed_item != &"":
		try_plant(soil, seed_item, z)
	EventBus.farm_changed.emit(z)
	return Result.success()


func try_plant(soil: Vector3i, seed_item: StringName, z: StringName = &"") -> Result:
	z = _z(z)
	var it := Database.item(seed_item)
	if it == null or it.seed_crop == &"":
		return Result.failure(NOT_A_SEED)
	var reason := model.can_plant(z, soil)
	if reason != &"":
		return Result.failure(reason)
	if not _cell_free(soil + Vector3i.UP):
		return Result.failure(FarmModel.NO_ROOM)
	if not session.inventory.remove(seed_item, 1):
		return Result.failure(NO_SEED)
	var crop_cell := soil + Vector3i.UP
	var k := model.plant(z, soil, it.seed_crop, session.day())
	_protect(k, crop_cell)
	EventBus.crop_planted.emit(crop_cell, it.seed_crop)
	EventBus.farm_changed.emit(z)
	return Result.success(k)


## Accepts the soil cell or the crop cell above it.
func soil_of(cell: Vector3i, z: StringName = &"") -> Vector3i:
	z = _z(z)
	if not model.is_tilled(z, cell) and model.is_tilled(z, cell + Vector3i.DOWN):
		return cell + Vector3i.DOWN
	return cell


func try_water(cell: Vector3i, z: StringName = &"") -> Result:
	z = _z(z)
	if not session.toolbelt.model.has_tool(ToolTypes.WATERING_CAN):
		return Result.failure(MISSING_TOOL)
	var soil := soil_of(cell, z)
	var reason := model.water(z, soil, session.day())
	if reason != &"":
		return Result.failure(reason)
	EventBus.crop_watered.emit(soil + Vector3i.UP)
	EventBus.farm_changed.emit(z)
	return Result.success()


func refill_can() -> Result:
	if not session.toolbelt.model.has_tool(ToolTypes.WATERING_CAN):
		return Result.failure(MISSING_TOOL)
	model.refill()
	EventBus.can_refilled.emit(model.can_water)
	return Result.success()


func try_harvest(crop_cell: Vector3i, z: StringName = &"") -> Result:
	z = _z(z)
	var c := model.crop_at(z, crop_cell)
	if c.is_empty():
		return Result.failure(FarmModel.NO_CROP)
	var def: CropDef = Database.crops[StringName(c["crop_id"])]
	var r := model.harvest(z, crop_cell, def, session.rng)
	if not r["ok"]:
		return Result.failure(r["reason"])
	var drops: Array = [{"item": def.harvest_item_id, "qty": r["qty"]}]
	if r["seeds"] > 0:
		drops.append({"item": def.seed_item_id, "qty": r["seeds"]})
	session.world_state.give_drops(drops, Vector3(crop_cell) + Vector3(0.5, 0.5, 0.5))
	if model.crop_at(z, crop_cell).is_empty() and z == zone():
		_unprotect(FarmModel.key(z, crop_cell))
	EventBus.crop_harvested.emit(crop_cell, def.id, r["qty"])
	EventBus.farm_changed.emit(z)
	return Result.success(r)


## Minimal sprinkler placement (plan P2B.9); Phase 3 Build mode takes this over.
func try_place_sprinkler(cell: Vector3i, z: StringName = &"") -> Result:
	z = _z(z)
	if session.inventory.count(SPRINKLER_ITEM) <= 0:
		return Result.failure(NO_SPRINKLER)
	if owned_plot_at(z, cell + Vector3i.DOWN) == null:
		return Result.failure(FarmModel.NOT_FARMABLE)
	if _world().get_voxel(cell + Vector3i.DOWN) == IVoxelWorld.AIR:
		return Result.failure(&"no_support")
	var reason := _rules().can_place(cell)
	if reason != TerrainRules.OK:
		return Result.failure(reason)
	session.inventory.remove(SPRINKLER_ITEM, 1)
	var k := model.place_sprinkler(z, cell)
	_protect(k, cell)
	EventBus.sprinkler_placed.emit(cell)
	EventBus.farm_changed.emit(z)
	return Result.success(k)


## DayRollover step `farm_growth` (spec 6.2, 10.5): every zone, loaded or not.
func daily_growth(day: int) -> void:
	var grew := model.daily_growth(day, Database.crops)
	for g in grew:
		var p := FarmModel.parse_key(g["key"])
		EventBus.crop_grew.emit(p[1], g["stage"])
	EventBus.farm_changed.emit(zone())


## Executes a farm action chosen by the player (aim dictionary "farm" entry).
func execute(a: Dictionary) -> Result:
	var z: StringName = a.get("zone", zone())
	match a.get("action", &""):
		&"till":
			return try_till(a["soil"], a.get("seed", &""), z)
		&"plant":
			return try_plant(a["soil"], a["seed"], z)
		&"water":
			return try_water(a["soil"], z)
		&"refill":
			return refill_can()
		&"harvest":
			return try_harvest(a["crop_cell"], z)
		&"place_sprinkler":
			return try_place_sprinkler(a["crop_cell"], z)
	return Result.failure(&"unknown_action")


## Farm aim for the tool selector (spec 10.4), or {} for the plain voxel rule.
func aim_for(cell: Vector3i, selected_item: StringName) -> Dictionary:
	var z := zone()
	var mat := session.terrain.material_at(cell)
	if mat == null:
		return {}
	var sel := Database.item(selected_item) if selected_item != &"" else null
	var seed_item: StringName = selected_item if sel and sel.seed_crop != &"" else &""
	var crop_cell := cell + Vector3i.UP
	var base := {"key": "farm:%d,%d,%d" % [cell.x, cell.y, cell.z], "kind": &"farm", "cell": cell,
		"tool": &"", "target_kind": &"", "tier_required": 0, "blocked": &"", "badge": &""}
	var farm := {"zone": z, "soil": cell, "crop_cell": crop_cell, "seed": seed_item}
	if mat.id == FARMLAND and model.is_tilled(z, cell):
		var crop := model.crop_at(z, crop_cell)
		if not crop.is_empty() and (Database.crops[StringName(crop["crop_id"])] as CropDef).is_ripe(int(crop["growth_days"])):
			return _aim(base, farm, &"harvest", &"", &"harvest")
		if crop.is_empty() and seed_item != &"":
			if not _cell_free(crop_cell):
				base["blocked"] = FarmModel.NO_ROOM
			return _aim(base, farm, &"plant", &"", &"plant")
		if crop.is_empty() and selected_item == SPRINKLER_ITEM and _cell_free(crop_cell):
			return _aim(base, farm, &"place_sprinkler", &"", &"place_sprinkler")
		if not model.is_watered_today(z, cell, session.day()):
			if model.can_water <= 0:
				base["badge"] = FarmModel.EMPTY_CAN
			return _aim(base, farm, &"water", ToolTypes.WATERING_CAN, &"water")
		return {}
	if mat.id in [&"mat_grass", &"mat_dirt"]:
		var hoe_in_hand := session.toolbelt.model.equipped == ToolTypes.HOE
		if seed_item != &"" or hoe_in_hand:
			var reason := farmable_reason(cell, z)
			if reason == &"":
				return _aim(base, farm, &"till", ToolTypes.HOE, &"till")
			if seed_item != &"" and reason != FarmModel.NOT_SOIL:
				base["blocked"] = reason
				return _aim(base, farm, &"till", &"", &"till")
	if selected_item == SPRINKLER_ITEM and owned_plot_at(z, cell) != null and _cell_free(crop_cell):
		return _aim(base, farm, &"place_sprinkler", &"", &"place_sprinkler")
	return {}


func _aim(base: Dictionary, farm: Dictionary, action: StringName, tool: StringName, kind: StringName) -> Dictionary:
	farm["action"] = action
	base["tool"] = tool
	base["target_kind"] = kind
	base["farm"] = farm
	return base


func _protect(k: String, cell: Vector3i) -> void:
	_rules().protect_support(cell, k, false)
	_rules().occupied_cells[cell] = k


func _unprotect(k: String) -> void:
	_rules().release_support(k)
	for c in _rules().occupied_cells.keys():
		if _rules().occupied_cells[c] == k:
			_rules().occupied_cells.erase(c)


## Called by Zone._ready: re-registers crop and sprinkler protection for the zone being loaded
## (TerrainRules is rebuilt per zone) and adds the farm view.
func bind_zone(z: StringName, zone_node: Node3D) -> void:
	var prefix := String(z) + "/"
	for k in model.crops.keys() + model.sprinklers.keys():
		if String(k).begins_with(prefix):
			_protect(k, FarmModel.parse_key(k)[1])
	if not model.tilled.is_empty() or owned_zone(z):
		var v := FarmView.new()
		v.name = "FarmView"
		v.zone_id = z
		zone_node.add_child(v)


func owned_zone(z: StringName) -> bool:
	for p in Database.plots.values():
		if p.zone_id == z:
			return true
	return false


func _on_voxel_dug(cell: Vector3i, material_id: StringName) -> void:
	if material_id == FARMLAND and model.is_tilled(zone(), cell):
		model.untill(zone(), cell)
		EventBus.farm_changed.emit(zone())


func to_dict() -> Dictionary:
	return model.to_dict()


func from_dict(d: Dictionary) -> void:
	model.from_dict(d)
