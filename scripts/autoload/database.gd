## Loads every content definition from res://resources/data/*.json into typed Resources
## and validates cross-references (spec 1.2, 3.9). Read-only at runtime.
extends Node

const DATA_DIR := "res://resources/data"

var items: Dictionary = {}          # StringName -> ItemDef
var materials: Dictionary = {}      # StringName -> VoxelMaterialDef
var materials_by_voxel: Dictionary = {}   # int -> VoxelMaterialDef
var loot_tables: Dictionary = {}    # StringName -> LootTableDef
var treasure_tables: Dictionary = {}
var fruit_trees: Dictionary = {}
var timber_trees: Dictionary = {}
var zones: Dictionary = {}          # StringName -> TerrainZoneDef
var mail_templates: Dictionary = {}
var stamina := StaminaConfig.new()
var discovery := DiscoveryConfig.new()
var starter_tools: Array[StringName] = []
var home_zone: StringName = &"zone_starter_cabin"
var home_bed_key: StringName = &"bed_01"
var load_errors: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_all(DATA_DIR)
	if OS.is_debug_build():
		for e in validate():
			push_error("Database: %s" % e)


func load_all(dir: String) -> void:
	load_errors.clear()
	items.clear(); materials.clear(); materials_by_voxel.clear(); loot_tables.clear()
	treasure_tables.clear(); fruit_trees.clear(); timber_trees.clear(); zones.clear(); mail_templates.clear()
	var items_json := _read(dir.path_join("items.json"))
	for d in items_json.get("items", []):
		var it := _item(d)
		items[it.id] = it
	for d in _read(dir.path_join("materials.json")).get("materials", []):
		var m := _material(d)
		materials[m.id] = m
		materials_by_voxel[m.voxel_id] = m
	var loot := _read(dir.path_join("loot.json"))
	for d in loot.get("loot_tables", []):
		var t := LootTableDef.new()
		t.id = StringName(d["id"])
		t.rolls = int(d.get("rolls", 1))
		t.entries = d.get("entries", [])
		t.guaranteed = d.get("guaranteed", [])
		loot_tables[t.id] = t
	for d in loot.get("treasure_tables", []):
		var t := TreasureTableDef.new()
		t.id = StringName(d["id"])
		t.entries = d.get("entries", [])
		t.fallback_coins_min = int(d.get("fallback_coins_min", 20))
		t.fallback_coins_max = int(d.get("fallback_coins_max", 40))
		treasure_tables[t.id] = t
	var world := _read(dir.path_join("world.json"))
	for d in world.get("fruit_trees", []):
		var f := FruitTreeDef.new()
		f.id = StringName(d["id"]); f.fruit_item_id = StringName(d["fruit_item_id"])
		f.fruit_min = int(d["fruit_min"]); f.fruit_max = int(d["fruit_max"]); f.regrow_days = int(d["regrow_days"])
		fruit_trees[f.id] = f
	for d in world.get("timber_trees", []):
		var t := TimberTreeDef.new()
		t.id = StringName(d["id"]); t.max_hp = int(d["max_hp"]); t.loot = StringName(d["loot"]); t.respawn_days = int(d["respawn_days"])
		timber_trees[t.id] = t
	for d in world.get("zones", []):
		var z := TerrainZoneDef.new()
		z.id = StringName(d["id"]); z.kind = StringName(d["kind"]); z.scene_path = d.get("scene_path", "")
		z.seed_mode = StringName(d.get("seed_mode", "FIXED")); z.persist_edits = bool(d.get("persist_edits", true))
		z.stream_db_key = d.get("stream_db_key", ""); z.treasure_table = StringName(d.get("treasure_table", ""))
		z.bounds_min = _v3i(d.get("bounds_min", [-64, -32, -64])); z.bounds_max = _v3i(d.get("bounds_max", [64, 64, 64]))
		zones[z.id] = z
	var home: Dictionary = world.get("home", {})
	home_zone = StringName(home.get("zone_id", "zone_starter_cabin"))
	home_bed_key = StringName(home.get("bed_key", "bed_01"))
	for d in _read(dir.path_join("mail_templates.json")).get("mail_templates", []):
		var m := MailTemplateDef.new()
		m.id = StringName(d["id"]); m.sender_id = StringName(d.get("sender_id", "system")); m.kind = StringName(d.get("kind", "LETTER"))
		m.subject_key = d.get("subject_key", ""); m.body_key = d.get("body_key", ""); m.pool_id = StringName(d.get("pool_id", ""))
		m.expires_after_days = int(d.get("expires_after_days", 0)); m.has_snack = bool(d.get("has_snack", false))
		m.attachments = (d.get("attachments", []) as Array).map(func(a):
			var c: Dictionary = a.duplicate()
			for k in ["qty", "amount"]:
				if c.has(k):
					c[k] = int(c[k])
			return c)
		mail_templates[m.id] = m
	var cfg := _read(dir.path_join("config.json"))
	var s: Dictionary = cfg.get("stamina", {})
	stamina = StaminaConfig.new()
	stamina.base_max = int(s.get("base_max", 100)); stamina.max_bonus_cap = int(s.get("max_bonus_cap", 50))
	stamina.low_thresholds_pct.assign((s.get("low_thresholds_pct", [25, 10]) as Array).map(func(v): return int(v)))
	stamina.sit_regen_per_sec = float(s.get("sit_regen_per_sec", 0.5)); stamina.forage_cost = int(s.get("forage_cost", 1))
	var dc: Dictionary = cfg.get("discovery", {})
	discovery = DiscoveryConfig.new()
	discovery.geode_item_id = StringName(dc.get("geode_item_id", "item_geode"))
	discovery.geode_pity = int(dc.get("geode_pity", 40)); discovery.chest_pity = int(dc.get("chest_pity", 150))
	starter_tools.assign((cfg.get("starter_kit", {}).get("tools", []) as Array).map(func(v): return StringName(v)))


func item(id: StringName) -> ItemDef:
	return items.get(id)


func max_stack(id: StringName) -> int:
	var it: ItemDef = items.get(id)
	return it.max_stack if it else 1


func material(id: StringName) -> VoxelMaterialDef:
	return materials.get(id)


func material_by_voxel(voxel_id: int) -> VoxelMaterialDef:
	return materials_by_voxel.get(voxel_id)


func voxel_id_of(material_id: StringName) -> int:
	var m: VoxelMaterialDef = materials.get(material_id)
	return m.voxel_id if m else -1


func templates_in_pool(pool_id: StringName) -> Array[MailTemplateDef]:
	var out: Array[MailTemplateDef] = []
	var ids := mail_templates.keys()
	ids.sort()
	for id in ids:
		if mail_templates[id].pool_id == pool_id:
			out.append(mail_templates[id])
	return out


## Cross-reference checks (spec 3.9, Phase 2 subset). Returns human-readable errors.
func validate() -> Array[String]:
	var errors: Array[String] = load_errors.duplicate()
	for id in items:
		var it: ItemDef = items[id]
		if not String(id).begins_with("item_"):
			errors.append("item id %s must start with item_" % id)
		if it.has_instance_data and it.max_stack != 1:
			errors.append("%s has instance data but max_stack != 1" % id)
		if it.category == &"TOOL" and it.tool == null:
			errors.append("%s is a TOOL without tool data" % id)
		if it.category == &"BLOCK" and not materials.has(it.block_material):
			errors.append("%s places unknown material %s" % [id, it.block_material])
	var voxel_ids := {}
	var bedrock_count := 0
	for id in materials:
		var m: VoxelMaterialDef = materials[id]
		if voxel_ids.has(m.voxel_id):
			errors.append("voxel_id %d used by %s and %s" % [m.voxel_id, voxel_ids[m.voxel_id], id])
		voxel_ids[m.voxel_id] = id
		if m.voxel_id == 0:
			errors.append("%s uses voxel_id 0 (reserved for air)" % id)
		if m.drop != &"" and not loot_tables.has(m.drop):
			errors.append("%s drops unknown loot table %s" % [id, m.drop])
		if m.special == VoxelMaterialDef.SPECIAL_BEDROCK:
			bedrock_count += 1
		if m.placeable:
			var has_item := items.values().any(func(it): return it.block_material == id)
			if not has_item:
				errors.append("placeable %s has no BLOCK item" % id)
	if bedrock_count != 1:
		errors.append("exactly one BEDROCK material required, found %d" % bedrock_count)
	for id in loot_tables:
		var t: LootTableDef = loot_tables[id]
		for e in t.entries + t.guaranteed:
			var item_id := String(e.get("item", ""))
			if item_id != "coins" and not items.has(StringName(item_id)):
				errors.append("loot %s references unknown item %s" % [id, item_id])
	for id in treasure_tables:
		for e in treasure_tables[id].entries:
			if e.get("kind", "") == "ITEM" and not items.has(StringName(e.get("item", ""))):
				errors.append("treasure %s references unknown item %s" % [id, e.get("item", "")])
			if e.get("kind", "") in ["BLUEPRINT", "DYE", "STICKER"] and (e.get("id_pool", []) as Array).is_empty():
				errors.append("treasure %s has an empty %s pool" % [id, e["kind"]])
	for id in fruit_trees:
		if not items.has(fruit_trees[id].fruit_item_id):
			errors.append("fruit tree %s yields unknown item" % id)
	for id in timber_trees:
		if not loot_tables.has(timber_trees[id].loot):
			errors.append("timber %s uses unknown loot %s" % [id, timber_trees[id].loot])
	for id in zones:
		var z: TerrainZoneDef = zones[id]
		if z.kind == TerrainZoneDef.DEEP_MINE and z.persist_edits:
			errors.append("deep mine zone %s must not persist edits" % id)
		if z.persist_edits and z.kind == TerrainZoneDef.OVERWORLD and z.stream_db_key == "":
			errors.append("zone %s persists edits but has no stream_db_key" % id)
		if z.treasure_table != &"" and not treasure_tables.has(z.treasure_table):
			errors.append("zone %s uses unknown treasure table" % id)
	if not zones.has(home_zone):
		errors.append("home zone %s unknown" % home_zone)
	for t in ["pool_care_exhausted", "pool_care_exhausted_repeat"]:
		if templates_in_pool(StringName(t)).is_empty():
			errors.append("mail pool %s is empty" % t)
	for tpl in templates_in_pool(&"pool_care_exhausted"):
		if not tpl.has_snack:
			errors.append("%s in snack pool has no snack" % tpl.id)
	for tpl in templates_in_pool(&"pool_care_exhausted_repeat"):
		if tpl.has_snack:
			errors.append("%s in repeat pool must not have a snack" % tpl.id)
	for id in mail_templates:
		for a in mail_templates[id].attachments:
			if a.get("type", "") == "item" and not items.has(StringName(a.get("item_id", ""))):
				errors.append("mail %s attaches unknown item" % id)
	for t in starter_tools:
		if not items.has(t) or items[t].tool == null:
			errors.append("starter tool %s invalid" % t)
	return errors


func _read(path: String) -> Dictionary:
	var res = load(path)
	var data: Variant = res.data if res is JSON else null
	if not (data is Dictionary):
		load_errors.append("cannot read %s" % path)
		return {}
	return data


func _v3i(a: Array) -> Vector3i:
	return Vector3i(int(a[0]), int(a[1]), int(a[2]))


func _item(d: Dictionary) -> ItemDef:
	var it := ItemDef.new()
	it.id = StringName(d["id"])
	it.name_key = d.get("name_key", "ITEM_%s" % String(d["id"]).to_upper())
	it.desc_key = d.get("desc_key", "")
	it.category = StringName(d.get("category", "RESOURCE"))
	it.max_stack = int(d.get("max_stack", 99))
	it.base_value = int(d.get("base_value", 0))
	it.sellable = bool(d.get("sellable", true))
	it.giftable = bool(d.get("giftable", true))
	it.tags.assign((d.get("tags", []) as Array).map(func(v): return StringName(v)))
	it.has_instance_data = bool(d.get("has_instance_data", false))
	it.block_material = StringName(d.get("block_material", ""))
	if d.has("tool"):
		var t := ToolData.new()
		var td: Dictionary = d["tool"]
		t.tool_type = StringName(td["tool_type"]); t.tier = int(td.get("tier", 1)); t.power = int(td.get("power", 1))
		t.strike_interval_sec = float(td.get("strike_interval_sec", 0.5)); t.stamina_cost = int(td.get("stamina_cost", 0))
		it.tool = t
	if d.has("food"):
		var f := FoodData.new()
		f.stamina_restore = int(d["food"].get("stamina_restore", 0)); f.pet_happiness = int(d["food"].get("pet_happiness", 0))
		it.food = f
	return it


func _material(d: Dictionary) -> VoxelMaterialDef:
	var m := VoxelMaterialDef.new()
	m.id = StringName(d["id"]); m.voxel_id = int(d["voxel_id"]); m.hardness_tier = int(d.get("hardness_tier", 1))
	m.hits = int(d.get("hits", 1)); m.wrong_tool_hits_multiplier = int(d.get("wrong_tool_hits_multiplier", 2))
	m.preferred_tool = StringName(d.get("preferred_tool", "SHOVEL")); m.drop = StringName(d.get("drop", ""))
	m.special = StringName(d.get("special", "NONE")); m.placeable = bool(d.get("placeable", false))
	m.stamina_cost = int(d.get("stamina_cost", 1)); m.color = Color.html(d.get("color", "#ffffff"))
	return m
