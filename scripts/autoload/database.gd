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
var crops: Dictionary = {}           # StringName -> CropDef
var plots: Dictionary = {}           # StringName -> PlotDef
var pieces: Dictionary = {}          # StringName -> BuildPieceDef
var build: Dictionary = {}           # config.json "build" (radii, angles, hold times, debug kit)
var recipes: Dictionary = {}         # StringName -> RecipeDef
var shops: Dictionary = {}           # StringName -> ShopDef
var jobs: Dictionary = {}            # StringName -> JobDef
var contracts: Dictionary = {}       # StringName -> ContractDef
var blueprints: Dictionary = {}      # StringName -> BlueprintDef
var outfits: Dictionary = {}         # StringName -> OutfitDef
var dyes: Dictionary = {}            # StringName -> DyeDef
var default_dyes: Array[StringName] = []
var economy: Dictionary = {"sell_pct": 50, "starting_coins": 0}
var npcs: Dictionary = {}            # StringName -> NpcDef
var friendship: Dictionary = {}
var pet_species: Dictionary = {}     # StringName -> PetSpeciesDef
var pet_accessories: Dictionary = {} # item id -> PetAccessoryDef
var pet_names: Array[String] = []
var pet_config: Dictionary = {}
var emotes: Dictionary = {}          # StringName -> EmoteDef
var default_emotes: Array[StringName] = []
var instruments: Dictionary = {}     # StringName -> InstrumentDef
var default_instruments: Array[StringName] = []
var farm := FarmConfig.new()
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
	crops.clear(); plots.clear(); pieces.clear()
	recipes.clear(); shops.clear(); jobs.clear(); contracts.clear(); blueprints.clear(); outfits.clear(); dyes.clear()
	npcs.clear(); pet_species.clear(); pet_accessories.clear(); emotes.clear(); instruments.clear()
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
	for d in world.get("plots", []):
		var pl := PlotDef.new()
		pl.id = StringName(d["id"]); pl.zone_id = StringName(d["zone_id"]); pl.min_cell = _v3i(d["min_cell"]); pl.max_cell = _v3i(d["max_cell"])
		pl.owned_from_start = bool(d.get("owned_from_start", false)); pl.price_coins = int(d.get("price_coins", 0))
		plots[pl.id] = pl
	for d in _read(dir.path_join("crops.json")).get("crops", []):
		var c := CropDef.new()
		c.id = StringName(d["id"]); c.seed_item_id = StringName(d["seed_item_id"]); c.harvest_item_id = StringName(d["harvest_item_id"])
		c.days_per_stage.assign((d["days_per_stage"] as Array).map(func(v): return int(v)))
		c.regrow_stage = int(d.get("regrow_stage", -1)); c.yield_min = int(d.get("yield_min", 1)); c.yield_max = int(d.get("yield_max", 1))
		c.seed_return_pct = int(d.get("seed_return_pct", 0)); c.color = Color.html(d.get("color", "#40a040"))
		crops[c.id] = c
	for d in _read(dir.path_join("pieces.json")).get("pieces", []):
		var p := _piece(d)
		pieces[p.id] = p
	_load_phase4(dir)
	_load_phase5(dir)
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
	var fc: Dictionary = cfg.get("farm", {})
	farm = FarmConfig.new()
	build = cfg.get("build", {})
	farm.can_capacity = int(fc.get("can_capacity", 20)); farm.sprinkler_radius = int(fc.get("sprinkler_radius", 1)); farm.till_stamina = int(fc.get("till_stamina", 1))


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
	ids.sort_custom(func(a, b): return String(a) < String(b))   # StringName sort is by address, not text
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
	for id in items:
		if items[id].category == &"SEED" and not crops.has(items[id].seed_crop):
			errors.append("seed %s plants unknown crop %s" % [id, items[id].seed_crop])
	for id in crops:
		var c: CropDef = crops[id]
		if not items.has(c.seed_item_id) or items[c.seed_item_id].seed_crop != id:
			errors.append("crop %s seed item %s missing or not linked" % [id, c.seed_item_id])
		if not items.has(c.harvest_item_id) or items[c.harvest_item_id].category != &"PRODUCE":
			errors.append("crop %s harvest item %s missing or not PRODUCE" % [id, c.harvest_item_id])
		if c.regrow_stage >= c.stage_count():
			errors.append("crop %s regrow_stage must be below the final stage" % id)
		if c.days_per_stage.is_empty() or c.stage_count() < 3 or c.stage_count() > 5:
			errors.append("crop %s needs 3 to 5 stages" % id)
	for id in plots:
		if not zones.has(plots[id].zone_id):
			errors.append("plot %s in unknown zone" % id)
	if not materials.has(&"mat_farmland"):
		errors.append("mat_farmland material missing")
	for id in pieces:
		var p: BuildPieceDef = pieces[id]
		if not items.has(p.item_id) or items[p.item_id].piece_id != id:
			errors.append("piece %s item %s missing or not linked" % [id, p.item_id])
		if p.footprint.is_empty():
			errors.append("piece %s has an empty footprint" % id)
		if p.fastener != BuildPieceDef.NONE and (p.fastener_sockets.is_empty() or p.hits_per_socket < 1):
			errors.append("piece %s is fastened but has no sockets or hits" % id)
		if not (p.layer in [BuildPieceDef.LAYER_FLOOR, BuildPieceDef.LAYER_BODY, BuildPieceDef.LAYER_WALL]):
			errors.append("piece %s has unknown layer %s" % [id, p.layer])
	for id in items:
		if items[id].category == &"BUILD_PIECE" and not pieces.has(items[id].piece_id):
			errors.append("build piece item %s places unknown piece" % id)
		if items[id].category == &"OUTFIT" and not outfits.has(items[id].outfit_id):
			errors.append("outfit item %s wears unknown outfit" % id)
	errors.append_array(_validate_phase4())
	errors.append_array(_validate_phase5())
	return errors


func _validate_phase4() -> Array[String]:
	var errors: Array[String] = []
	var known := func(id): return items.has(StringName(id))
	for id in shops:
		for e in shops[id].stock:
			if not known.call(e["item"]):
				errors.append("shop %s sells unknown item %s" % [id, e["item"]])
	for id in recipes:
		var r: RecipeDef = recipes[id]
		if r.inputs.is_empty() or r.inputs.size() > 6 or r.outputs.is_empty() or r.outputs.size() > 3:
			errors.append("recipe %s needs 1-6 inputs and 1-3 outputs" % id)
		var seen := {}
		for e in r.inputs + r.outputs:
			if not known.call(e["item"]):
				errors.append("recipe %s uses unknown item %s" % [id, e["item"]])
		for e in r.inputs:
			if seen.has(e["item"]):
				errors.append("recipe %s repeats input %s" % [id, e["item"]])
			seen[e["item"]] = true
		if r.required_job != &"" and not jobs.has(r.required_job):
			errors.append("recipe %s needs unknown job" % id)
	for id in contracts:
		var c: ContractDef = contracts[id]
		if not jobs.has(c.job_id):
			errors.append("contract %s has unknown job" % id)
		if c.kind == &"BUILD_BLUEPRINT" and not blueprints.has(c.blueprint):
			errors.append("contract %s has unknown blueprint" % id)
		for e in c.items + c.provided:
			if not known.call(e["item"]):
				errors.append("contract %s uses unknown item %s" % [id, e["item"]])
	for id in blueprints:
		for p in blueprints[id].pieces:
			if not pieces.has(p["piece_id"]):
				errors.append("blueprint %s uses unknown piece" % id)
	for id in outfits:
		var o: OutfitDef = outfits[id]
		if not (o.slot in OutfitDef.SLOTS):
			errors.append("outfit %s has unknown slot" % id)
		if o.default_dye_id != &"" and not dyes.has(o.default_dye_id):
			errors.append("outfit %s default dye unknown" % id)
	for id in dyes:
		if dyes[id].name_key == "":
			errors.append("dye %s has no name_key" % id)
	for d in default_dyes:
		if not dyes.has(d):
			errors.append("default dye %s unknown" % d)
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
	it.seed_crop = StringName(d.get("seed_crop", ""))
	it.piece_id = StringName(d.get("piece_id", ""))
	it.outfit_id = StringName(d.get("outfit_id", ""))
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


static func _amounts(a: Array) -> Array:
	return a.map(func(e): return {"item": StringName(e["item"]), "qty": int(e["qty"])})


func _load_phase4(dir: String) -> void:
	var eco := _read(dir.path_join("economy.json"))
	economy = {"sell_pct": int(eco.get("economy", {}).get("sell_pct", 50)), "starting_coins": int(eco.get("economy", {}).get("starting_coins", 0))}
	for d in eco.get("shops", []):
		var sh := ShopDef.new()
		sh.id = StringName(d["id"]); sh.buy_pct = int(d.get("buy_pct", 100)); sh.sell_pct = int(d.get("sell_pct", 100))
		sh.stock = (d.get("stock", []) as Array).map(func(e): return {"item": StringName(e["item"]), "daily": int(e.get("daily", -1))})
		shops[sh.id] = sh
	for d in _read(dir.path_join("recipes.json")).get("recipes", []):
		var r := RecipeDef.new()
		r.id = StringName(d["id"]); r.station = StringName(d.get("station", "HAND"))
		r.inputs = _amounts(d.get("inputs", [])); r.outputs = _amounts(d.get("outputs", []))
		r.coin_cost = int(d.get("coin_cost", 0)); r.craft_time_sec = float(d.get("craft_time_sec", 0.0))
		r.required_job = StringName(d.get("required_job", "")); r.required_rank = int(d.get("required_rank", 0))
		r.unlock = StringName(d.get("unlock", "DEFAULT")); r.xp_reward = int(d.get("xp_reward", 0))
		recipes[r.id] = r
	var jj := _read(dir.path_join("jobs.json"))
	for d in jj.get("jobs", []):
		var j := JobDef.new()
		j.id = StringName(d["id"])
		j.ranks_xp.assign((d.get("ranks_xp", [0]) as Array).map(func(v): return int(v)))
		jobs[j.id] = j
	for d in jj.get("contracts", []):
		var c := ContractDef.new()
		c.id = StringName(d["id"]); c.job_id = StringName(d["job_id"]); c.kind = StringName(d["kind"])
		c.blueprint = StringName(d.get("blueprint", "")); c.items = _amounts(d.get("items", [])); c.provided = _amounts(d.get("provided", []))
		c.pay = int(d.get("pay", 0)); c.xp = int(d.get("xp", 0)); c.days = int(d.get("days", 3)); c.min_rank = int(d.get("min_rank", 0))
		contracts[c.id] = c
	for d in jj.get("blueprints", []):
		var b := BlueprintDef.new()
		b.id = StringName(d["id"]); b.zone_id = StringName(d["zone_id"]); b.site_min = _v3i(d["site_min"]); b.site_max = _v3i(d["site_max"])
		b.pieces = (d.get("pieces", []) as Array).map(func(p): return {"piece_id": StringName(p["piece_id"]), "cell": _v3i(p["cell"]), "rot": int(p.get("rot", 0))})
		blueprints[b.id] = b
	var oo := _read(dir.path_join("outfits.json"))
	for d in oo.get("outfits", []):
		var o := OutfitDef.new()
		o.id = StringName(d["id"]); o.item_id = StringName(d["item_id"]); o.slot = StringName(d["slot"])
		o.color = Color.html(d.get("color", "#ffffff")); o.dyeable = bool(d.get("dyeable", true))
		o.default_dye_id = StringName(d.get("default_dye_id", ""))
		o.hide_body_regions.assign((d.get("hide_body_regions", []) as Array).map(func(v): return StringName(v)))
		outfits[o.id] = o
	for d in oo.get("dyes", []):
		var y := DyeDef.new()
		y.id = StringName(d["id"]); y.name_key = d.get("name_key", ""); y.color = Color.html(d.get("color", "#ffffff"))
		dyes[y.id] = y
	default_dyes.assign((oo.get("default_dyes", []) as Array).map(func(v): return StringName(v)))


func _load_phase5(dir: String) -> void:
	var nn := _read(dir.path_join("npcs.json"))
	for d in nn.get("npcs", []):
		var n := NpcDef.new()
		n.id = StringName(d["id"]); n.name_key = d.get("name_key", ""); n.color = Color.html(d.get("color", "#ffffff"))
		n.shop_id = StringName(d.get("shop_id", "")); n.job_id = StringName(d.get("job_id", "")); n.is_curator = bool(d.get("is_curator", false))
		var prefs := {}
		for k in d.get("gift_prefs", {}):
			prefs[k] = (d["gift_prefs"][k] as Array).map(func(v): return StringName(v))
		n.gift_prefs = prefs
		n.schedule = (d.get("schedule", []) as Array).map(func(e): return {"from": int(e["from"]), "marker": StringName(e["marker"])})
		n.dialogue = d.get("dialogue", {})
		npcs[n.id] = n
	friendship = nn.get("friendship", {})
	for k in friendship:
		if friendship[k] is float:
			friendship[k] = int(friendship[k])
	friendship["letters"] = (friendship.get("letters", []) as Array).map(func(e): return {"threshold": int(e["threshold"]), "template": StringName(e["template"])})
	var pp := _read(dir.path_join("pets.json"))
	for d in pp.get("species", []):
		var sp := PetSpeciesDef.new()
		sp.id = StringName(d["id"])
		for k in ["walk_speed", "run_speed", "follow_distance", "teleport_distance", "idle_after", "wander_after", "wander_radius"]:
			sp.set(k, float(d.get(k, sp.get(k))))
		sp.accessory_bones = d.get("accessory_bones", sp.accessory_bones)
		sp.favorite_food_tags.assign((d.get("favorite_food_tags", []) as Array).map(func(v): return StringName(v)))
		sp.variants.assign((d.get("variants", []) as Array).map(func(v): return Color.html(v)))
		sp.size = _v3(d.get("size", [0.5, 0.6, 0.9]))
		pet_species[sp.id] = sp
	for d in pp.get("accessories", []):
		var a := PetAccessoryDef.new()
		a.item_id = StringName(d["item_id"]); a.slot = StringName(d["slot"]); a.dyeable = bool(d.get("dyeable", true))
		a.species.assign((d.get("species", []) as Array).map(func(v): return StringName(v)))
		a.default_dye_id = StringName(d.get("default_dye_id", "")); a.color = Color.html(d.get("color", "#ffffff"))
		pet_accessories[a.item_id] = a
	pet_names.assign(pp.get("names", []))
	pet_config = pp.get("config", {})
	var ee := _read(dir.path_join("emotes.json"))
	for d in ee.get("emotes", []):
		var e := EmoteDef.new()
		e.id = StringName(d["id"]); e.duration_sec = float(d.get("duration_sec", 1.5))
		e.pet_reaction = StringName(d.get("pet_reaction", "")); e.npc_reaction = StringName(d.get("npc_reaction", ""))
		emotes[e.id] = e
	default_emotes.assign((ee.get("default_emotes", []) as Array).map(func(v): return StringName(v)))
	for d in ee.get("instruments", []):
		var i := InstrumentDef.new()
		i.id = StringName(d["id"]); i.base_hz = float(d.get("base_hz", 440.0)); i.wave = StringName(d.get("wave", "sine"))
		instruments[i.id] = i
	default_instruments.assign((ee.get("default_instruments", []) as Array).map(func(v): return StringName(v)))


func _validate_phase5() -> Array[String]:
	var errors: Array[String] = []
	for id in npcs:
		var n: NpcDef = npcs[id]
		if n.shop_id != &"" and not shops.has(n.shop_id):
			errors.append("npc %s has unknown shop" % id)
		if n.job_id != &"" and not jobs.has(n.job_id):
			errors.append("npc %s has unknown job" % id)
		for k in n.gift_prefs:
			for it in n.gift_prefs[k]:
				if not items.has(it):
					errors.append("npc %s prefers unknown item %s" % [id, it])
		if n.schedule.is_empty():
			errors.append("npc %s has no schedule" % id)
	for l in friendship.get("letters", []):
		if not mail_templates.has(l["template"]):
			errors.append("friendship letter %s unknown" % l["template"])
	for id in pet_accessories:
		var a: PetAccessoryDef = pet_accessories[id]
		if not items.has(id) or items[id].category != &"PET_ACCESSORY":
			errors.append("pet accessory %s has no PET_ACCESSORY item" % id)
		if not (a.slot in PetAccessoryDef.SLOTS):
			errors.append("pet accessory %s has unknown slot" % id)
		if a.species.is_empty():
			errors.append("pet accessory %s fits no species" % id)
		for sp in a.species:
			if not pet_species.has(sp):
				errors.append("pet accessory %s names unknown species %s" % [id, sp])
	for id in items:
		if items[id].category == &"PET_ACCESSORY" and not pet_accessories.has(id):
			errors.append("PET_ACCESSORY item %s has no accessory definition" % id)
		if items[id].category == &"PET_FOOD" and items[id].food == null:
			errors.append("PET_FOOD %s has no food data" % id)
	for sp in pet_species.values():
		if sp.variants.size() != 3:
			errors.append("pet species %s needs 3 color variants" % sp.id)
	for e in default_emotes + default_instruments:
		if not emotes.has(e) and not instruments.has(e):
			errors.append("default unlock %s unknown" % e)
	for id in mail_templates:
		for a in mail_templates[id].attachments:
			match a.get("type", ""):
				"contract":
					if not contracts.has(StringName(a.get("contract_id", ""))):
						errors.append("mail %s attaches unknown contract" % id)
				"unlock_emote":
					if not emotes.has(StringName(a.get("id", ""))):
						errors.append("mail %s unlocks unknown emote" % id)
				"unlock_dye":
					if not dyes.has(StringName(a.get("id", ""))):
						errors.append("mail %s unlocks unknown dye" % id)
	return errors


func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _piece(d: Dictionary) -> BuildPieceDef:
	var p := BuildPieceDef.new()
	p.id = StringName(d["id"]); p.item_id = StringName(d["item_id"]); p.layer = StringName(d.get("layer", "BODY"))
	p.grid = StringName(d.get("grid", "STRUCTURE_1M")); p.fastener = StringName(d.get("fastener", "NONE"))
	p.hits_per_socket = int(d.get("hits_per_socket", 0))
	p.requires_support = bool(d.get("requires_support", true)); p.provides_support = bool(d.get("provides_support", false))
	p.footprint.assign((d.get("footprint", [[0, 0, 0]]) as Array).map(func(a): return _v3i(a)))
	p.opening.assign((d.get("opening", []) as Array).map(func(a): return _v3i(a)))
	p.fastener_sockets.assign((d.get("fastener_sockets", []) as Array).map(func(a): return _v3(a)))
	p.accepts.assign((d.get("accepts", []) as Array).map(func(v): return StringName(v)))
	p.snap_sockets = (d.get("snap_sockets", []) as Array).map(func(s): return {"position": _v3(s["position"]),
		"provides": StringName(s["provides"]), "attach_offset": _v3i(s["attach_offset"]), "attach_rot": int(s.get("attach_rot", 0))})
	p.interactions = (d.get("interactions", []) as Array).map(func(i):
		var o := {"kind": StringName(i["kind"])}
		o["seats"] = (i.get("seats", []) as Array).map(func(a): return _v3(a))
		o["exits"] = (i.get("exits", []) as Array).map(func(a): return _v3(a))
		o["toggle_states"] = int(i.get("toggle_states", 0)); o["slots"] = int(i.get("slots", 0))
		o["stamina_regen_per_sec"] = float(i.get("stamina_regen_per_sec", 0.0))
		return o)
	p.parts = (d.get("parts", []) as Array).map(func(b): return {"size": _v3(b["size"]), "center": _v3(b["center"]), "solid": bool(b.get("solid", true))})
	p.color = Color.html(d.get("color", "#ffffff"))
	return p


func _material(d: Dictionary) -> VoxelMaterialDef:
	var m := VoxelMaterialDef.new()
	m.id = StringName(d["id"]); m.voxel_id = int(d["voxel_id"]); m.hardness_tier = int(d.get("hardness_tier", 1))
	m.hits = int(d.get("hits", 1)); m.wrong_tool_hits_multiplier = int(d.get("wrong_tool_hits_multiplier", 2))
	m.preferred_tool = StringName(d.get("preferred_tool", "SHOVEL")); m.drop = StringName(d.get("drop", ""))
	m.special = StringName(d.get("special", "NONE")); m.placeable = bool(d.get("placeable", false))
	m.stamina_cost = int(d.get("stamina_cost", 1)); m.color = Color.html(d.get("color", "#ffffff"))
	return m
