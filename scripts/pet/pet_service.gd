## Pet adoption, care, accessories and daily reset (spec 1.8, 7.1, P5.6 to P5.10).
class_name PetService
extends Node

var session: GameSession
var pets: Array = []            # pet states (v1: at most one)
var model := PetModel.new()
var accessories := PetAccessoryModel.new()
var node: Pet
var path_override: PetPathProvider   # tests


func setup(s: GameSession) -> void:
	session = s
	model = PetModel.new(Database.pet_config)


func _ready() -> void:
	EventBus.zone_loaded.connect(_on_zone_loaded)
	EventBus.pet_nudge_requested.connect(_on_nudge)
	EventBus.player_emoted.connect(_on_emoted)
	EventBus.pet_called.connect(_on_called)


func _exit_tree() -> void:
	for pair in [[EventBus.zone_loaded, _on_zone_loaded], [EventBus.pet_nudge_requested, _on_nudge],
			[EventBus.player_emoted, _on_emoted], [EventBus.pet_called, _on_called]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	if is_instance_valid(node):
		node.queue_free()


func pet() -> Dictionary:
	return pets[0] if not pets.is_empty() else {}


func has_pet() -> bool:
	return not pets.is_empty()


func adopt(species: StringName, variant: int, pet_name: String) -> Result:
	if has_pet():
		return Result.failure(&"already_has_pet")
	if not Database.pet_species.has(species):
		return Result.failure(&"unknown_species")
	var n := pet_name.strip_edges()
	if n == "":
		n = Database.pet_names[0] if not Database.pet_names.is_empty() else "Buddy"
	pets.append(model.new_pet("pet_0001", species, variant, n.substr(0, 16)))
	spawn()
	EventBus.pet_adopted.emit(species, n)
	return Result.success()


## Creates the pet body next to the player in the current zone.
func spawn() -> void:
	if not has_pet() or not is_instance_valid(SceneRouter.player):
		return
	if is_instance_valid(node):
		node.queue_free()
	node = Pet.create(session, pet())
	var parent: Node = SceneRouter.player.get_parent()
	parent.add_child(node)
	node.provider = _provider()
	node.teleport_next_to_player()


func _provider() -> PetPathProvider:
	if path_override:
		return path_override
	var z = SceneRouter.current_zone
	if z is Zone and z.terrain_node is VoxelTerrain:
		return VoxelPathProvider.new(z.terrain_node)
	if is_instance_valid(node) and node.is_inside_tree():
		return NavmeshPathProvider.new(node.get_world_3d().navigation_map)
	return PetPathProvider.new()


func _on_zone_loaded(_z: StringName) -> void:
	if not has_pet():
		return
	if not is_instance_valid(node):
		spawn()
		return
	node.provider = _provider()
	node.facts["zone_changed"] = true
	node.teleport_next_to_player()


func _on_nudge(cells: Array) -> void:
	if is_instance_valid(node):
		node.nudge_out_of(cells)


func _on_emoted(_emote_id: StringName, at: Vector3) -> void:
	if is_instance_valid(node) and node.global_position.distance_to(at) <= float(Database.pet_config.get("emote_react_radius", 8.0)):
		node.facts["emote"] = true


func _on_called() -> void:
	if is_instance_valid(node):
		node.facts["call"] = true


func pat() -> int:
	if not has_pet():
		return 0
	var gain := model.pat(pet(), session.day())
	if is_instance_valid(node):
		node.facts["pat"] = true
	EventBus.pet_happiness_changed.emit(int(pet()["happiness"]))
	return gain


## First owned item the pet accepts (for the Y prompt), or &"".
func feedable_item() -> StringName:
	if not has_pet():
		return &""
	var sp: PetSpeciesDef = Database.pet_species[StringName(pet()["species_id"])]
	for st in session.inventory.model.slots:
		if st == null:
			continue
		var it := Database.item(st["item_id"])
		if it and it.food and (it.category == &"PET_FOOD" or (it.category == &"FOOD" and PetModel.is_favorite(it, sp))):
			return it.id
	return &""


func try_feed(item_id: StringName) -> Result:
	if not has_pet():
		return Result.failure(&"no_pet")
	if session.inventory.count(item_id) <= 0:
		return Result.failure(PetModel.NO_ITEM)
	var sp: PetSpeciesDef = Database.pet_species[StringName(pet()["species_id"])]
	var r := model.feed(pet(), Database.item(item_id), sp, session.day())
	if not r["ok"]:
		return Result.failure(r["reason"])
	session.inventory.remove(item_id, 1)
	if is_instance_valid(node):
		node.facts["feed"] = true
	EventBus.pet_fed.emit(item_id, r["gain"])
	EventBus.pet_happiness_changed.emit(int(pet()["happiness"]))
	return Result.success(r)


func equip_accessory(backpack_slot: int) -> Result:
	if not has_pet():
		return Result.failure(&"no_pet")
	var r := accessories.equip(pet(), session.inventory.model, backpack_slot)
	if not r["ok"]:
		return Result.failure(r["reason"])
	_accessory_changed(r["slot"])
	return Result.success(r["slot"])


func remove_accessory(slot: StringName) -> Result:
	if not has_pet():
		return Result.failure(&"no_pet")
	var r := accessories.remove(pet(), session.inventory.model, slot)
	if not r["ok"]:
		return Result.failure(r["reason"])
	_accessory_changed(slot)
	return Result.success()


func set_accessory_dye(slot: StringName, dye_id: StringName) -> Result:
	var st = pet().get("accessories", {}).get(String(slot)) if has_pet() else null
	if st == null:
		return Result.failure(&"empty")
	if not session.unlocks.model.is_unlocked(&"DYE", dye_id):
		return Result.failure(&"locked")
	st["data"]["dye"] = String(dye_id)
	_accessory_changed(slot)
	return Result.success()


func _accessory_changed(slot: StringName) -> void:
	if is_instance_valid(node):
		node.refresh_accessories()
	EventBus.inventory_changed.emit()
	EventBus.pet_accessory_changed.emit(slot)


## Bowls (FEED_BOWL pieces) in the current zone.
func bowls() -> Array:
	return session.build.pieces_in(SceneRouter.current_zone_id).filter(func(p):
		return not Database.pieces[StringName(p["piece_id"])].interaction(&"FEED_BOWL").is_empty())


func _bowl_food(uid: String) -> StringName:
	var c := session.storage.container(uid)
	for st in c.slots:
		if st and Database.item(st["item_id"]).category in [&"PET_FOOD", &"FOOD"]:
			return st["item_id"]
	return &""


## Self-feed at rollover (spec 7.1): one bowl with food feeds the pet once per day.
func _self_feed(day: int) -> bool:
	if not has_pet() or int(pet()["fed_day"]) == day:
		return false
	for b in session.build.pieces.values():
		if Database.pieces[StringName(b["piece_id"])].interaction(&"FEED_BOWL").is_empty():
			continue
		var food := _bowl_food(b["uid"])
		if food == &"":
			continue
		var sp: PetSpeciesDef = Database.pet_species[StringName(pet()["species_id"])]
		var r := model.feed(pet(), Database.item(food), sp, day)
		if r["ok"]:
			session.storage.container(b["uid"]).remove(food, 1)
			EventBus.pet_fed.emit(food, r["gain"])
			return true
	return false


## Walking to a bowl in the zone (GO_TO_BOWL -> EAT).
func eat_from_bowl() -> void:
	for b in bowls():
		var food := _bowl_food(b["uid"])
		if food != &"":
			var sp: PetSpeciesDef = Database.pet_species[StringName(pet()["species_id"])]
			if model.feed(pet(), Database.item(food), sp, session.day())["ok"]:
				session.storage.container(b["uid"]).remove(food, 1)
			return


func nearest_bed_distance(from: Vector3) -> float:
	var best := INF
	for p in session.build.pieces_in(SceneRouter.current_zone_id):
		if not Database.pieces[StringName(p["piece_id"])].interaction(&"PET_BED").is_empty():
			best = minf(best, from.distance_to(Vector3(p["cell"]) + Vector3(0.5, 0, 0.5)))
	return best


## DayRollover step `pet_reset` (spec 6.2): bowl self-feed, daily find, drift, floor.
func daily_reset(day: int) -> void:
	if not has_pet():
		return
	_self_feed(day)
	var found := model.daily_find(pet(), day, session.rng)
	if found != &"":
		session.world_state.give_drops([{"item": found, "qty": 1}], Vector3.ZERO)
		EventBus.pet_found_item.emit(found)
	model.drift(pet())
	EventBus.pet_happiness_changed.emit(int(pet()["happiness"]))


func update_bowl_target() -> void:
	if not is_instance_valid(node):
		return
	node.bowl_target = null
	for b in bowls():
		if _bowl_food(b["uid"]) != &"":
			node.bowl_target = Vector3(b["cell"]) + Vector3(0.5, 0, 0.5)
			return


func _physics_process(_delta: float) -> void:
	update_bowl_target()


func to_dict() -> Array:
	return pets.duplicate(true)


func from_dict(a: Array) -> void:
	pets.clear()
	for p in a:
		if not Database.pet_species.has(StringName(p.get("species_id", ""))):
			continue
		var acc := {}
		for slot in ["HEAD", "NECK", "BODY"]:
			var st = p.get("accessories", {}).get(slot)
			acc[slot] = null if st == null or not Database.pet_accessories.has(StringName(st["item_id"])) else {"item_id": String(st["item_id"]), "data": (st.get("data", {}) as Dictionary).duplicate(true)}
		pets.append({"pet_uid": String(p.get("pet_uid", "pet_0001")), "species_id": String(p["species_id"]), "name": String(p.get("name", "")),
			"color_variant": int(p.get("color_variant", 0)), "happiness": clampi(int(p.get("happiness", 60)), model.floor_value(), 100),
			"fed_day": int(p.get("fed_day", 0)), "pat_day": int(p.get("pat_day", 0)), "found_day": int(p.get("found_day", 0)), "accessories": acc})
