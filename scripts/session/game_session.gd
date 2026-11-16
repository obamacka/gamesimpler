## Owns every gameplay service for one play session (spec 1.3). Not an autoload, so tests
## build a fresh session per case. `GameSession.current` is the active one.
class_name GameSession
extends Node

static var current: GameSession

var rng := RngStreams.new()
var rollover := DayRollover.new()
var inventory: InventoryService
var toolbelt: ToolBeltService
var wallet: WalletService
var unlocks: UnlockService
var stamina: StaminaService
var discovery: DiscoveryService
var terrain: TerrainService
var world_state: WorldStateService
var mail: MailService
var housing: HousingService
var sleep: SleepDirector
var farm: FarmService
var build: BuildService
var economy: EconomyService
var jobs: JobService
var outfit: OutfitService
var storage: StorageService
var npcs: NpcService
var pets: PetService
var hotbar := HotbarModel.new()
var exhaustion := {"last_snack_day": 0, "count_total": 0}
var zone_root: Node3D
var player: Node3D


static func create(seed_value: int = 918273, world: IVoxelWorld = null) -> GameSession:
	var s := GameSession.new()
	s.name = "GameSession"
	s.rng = RngStreams.new(seed_value)
	s._build(world if world else FakeVoxelWorld.new())
	return s


func _build(world: IVoxelWorld) -> void:
	inventory = _add(InventoryService.new(), "InventoryService")
	toolbelt = _add(ToolBeltService.new(), "ToolBeltService")
	wallet = _add(WalletService.new(), "WalletService")
	unlocks = _add(UnlockService.new(), "UnlockService")
	stamina = _add(StaminaService.new(), "StaminaService")
	discovery = _add(DiscoveryService.new(), "DiscoveryService")
	world_state = _add(WorldStateService.new(), "WorldStateService")
	terrain = _add(TerrainService.new(), "TerrainService")
	mail = _add(MailService.new(), "MailService")
	housing = _add(HousingService.new(), "HousingService")
	sleep = _add(SleepDirector.new(), "SleepDirector")
	farm = _add(FarmService.new(), "FarmService")
	build = _add(BuildService.new(), "BuildService")
	economy = _add(EconomyService.new(), "EconomyService")
	jobs = _add(JobService.new(), "JobService")
	outfit = _add(OutfitService.new(), "OutfitService")
	storage = _add(StorageService.new(), "StorageService")
	npcs = _add(NpcService.new(), "NpcService")
	pets = _add(PetService.new(), "PetService")
	terrain.setup(self, world)
	world_state.setup(self)
	mail.setup(self)
	sleep.setup(self)
	farm.setup(self)
	build.setup(self)
	economy.setup(self)
	jobs.setup(self)
	outfit.setup(self)
	storage.setup(self)
	npcs.setup(self)
	pets.setup(self)
	rollover.register(&"pet_reset", func(day): pets.daily_reset(day))
	housing.extra_plots = func(z: StringName) -> Array: return jobs.site_plots(z)
	rollover.register(&"restock", func(day):
		economy.restock(day)
		jobs.expire_due(day))
	rollover.register(&"clock", func(day): GameClock.model.set_morning(day))
	rollover.register(&"world_respawn", func(day): world_state.respawn_due(day))
	rollover.register(&"terrain_reset", func(day): terrain.daily_reset(day))
	rollover.register(&"farm_growth", func(day): farm.daily_growth(day))
	rollover.register(&"mail_deliver", func(day): mail.deliver_due(day))
	rollover.register(&"day_started", func(day):
		stamina.model.new_day()
		EventBus.day_started.emit(day))


func _add(n: Node, node_name: String) -> Node:
	n.name = node_name
	add_child(n)
	return n


func _enter_tree() -> void:
	current = self
	EventBus.clock_late_night.connect(_on_late_night)


func _exit_tree() -> void:
	if EventBus.clock_late_night.is_connected(_on_late_night):
		EventBus.clock_late_night.disconnect(_on_late_night)
	if current == self:
		current = null


## New-game defaults: starter tools (incl. HOE and full WATERING_CAN), full stamina, day 1
## morning, and the welcome letter with starter seeds in the mailbox (spec 10.7).
func new_game() -> void:
	for t in Database.starter_tools:
		toolbelt.model.grant(t)
	stamina.model.configure(Database.stamina)
	farm.model.refill()
	wallet.model.coins = int(Database.economy["starting_coins"])
	for d in Database.default_dyes:
		unlocks.model.grant(&"DYE", d)
	for e in Database.default_emotes:
		unlocks.model.grant(&"EMOTE", e)
	for i in Database.default_instruments:
		unlocks.model.grant(&"INSTRUMENT", i)
	GameClock.model.set_morning(1)
	var welcome: MailTemplateDef = Database.mail_templates.get(&"mail_tpl_welcome")
	if welcome:
		mail.schedule(welcome, 1)
		mail.deliver_due(1)
	var adoption: MailTemplateDef = Database.mail_templates.get(&"mail_tpl_pet_adoption")
	if adoption:
		mail.schedule(adoption, 2)   # D11: the pet arrives on day 2


func day() -> int:
	return GameClock.model.day


func _on_late_night() -> void:
	if player and player.has_method("request_sleep"):
		player.request_sleep(&"late_night")
	else:
		sleep.begin_sleep(&"late_night")


## Phase 2 save sections (spec 3.5). Phase 6 adds files, slots and the voxel DB.
func to_dict() -> Dictionary:
	return {
		"schema_version": 1,
		"rng": rng.to_dict(),
		"clock": GameClock.model.to_dict(),
		"player": stamina.model.to_dict().merged({"home": housing.to_dict(), "hotbar_index": hotbar.selected, "outfit": outfit.model.to_dict()}),
		"exhaustion": exhaustion.duplicate(),
		"toolbelt": toolbelt.model.to_dict(),
		"inventory": inventory.model.to_dict().merged({"hotbar_refs": hotbar.refs.duplicate(), "containers": storage.to_dict()}),
		"wallet": wallet.model.to_dict(),
		"unlocks": unlocks.model.to_dict(),
		"terrain": {"damaged": terrain.dig.to_dict()},
		"world": world_state.to_dict(),
		"discovery": discovery.model.to_dict(),
		"mail": mail.model.to_dict(),
		"farm": farm.to_dict(),
		"housing": housing.plots_to_dict(),
		"build": build.to_dict(),
		"jobs": jobs.to_dict(),
		"shops": economy.stock_to_dict(),
		"npcs": npcs.model.to_dict(),
		"pets": pets.to_dict(),
	}


func from_dict(d: Dictionary) -> void:
	rng.from_dict(d.get("rng", {}))
	GameClock.model.from_dict(d.get("clock", {}))
	stamina.model.from_dict(d.get("player", {}))
	housing.from_dict(d.get("player", {}).get("home", {}))
	var ex: Dictionary = d.get("exhaustion", {})
	exhaustion = {"last_snack_day": int(ex.get("last_snack_day", 0)), "count_total": int(ex.get("count_total", 0))}
	toolbelt.model.from_dict(d.get("toolbelt", {}))
	inventory.model.from_dict(d.get("inventory", {}))
	wallet.model.from_dict(d.get("wallet", {}))
	unlocks.model.from_dict(d.get("unlocks", {}))
	terrain.dig.from_dict(d.get("terrain", {}).get("damaged", {}))
	world_state.from_dict(d.get("world", {}))
	discovery.model.from_dict(d.get("discovery", {}))
	mail.model.from_dict(d.get("mail", {}))
	farm.from_dict(d.get("farm", {}))
	housing.plots_from_dict(d.get("housing", {}))
	build.from_dict(d.get("build", {}))
	jobs.from_dict(d.get("jobs", {}))
	if d.has("shops"):
		economy.stock_from_dict(d["shops"])
	outfit.model.from_dict(d.get("player", {}).get("outfit", {}))
	storage.from_dict(d.get("inventory", {}).get("containers", {}))
	npcs.model.from_dict(d.get("npcs", {}))
	pets.from_dict(d.get("pets", []))
	hotbar.from_dict({"hotbar_refs": d.get("inventory", {}).get("hotbar_refs", hotbar.refs),
		"hotbar_index": d.get("player", {}).get("hotbar_index", 0)})
