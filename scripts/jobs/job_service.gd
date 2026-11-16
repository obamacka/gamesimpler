## Builder and Tailor jobs (spec 1.8, P4.6): accept, submit, abandon; blueprint completion
## from piece_fastened; craft progress from item_crafted; pay through the coordinator;
## provided materials and receipts by mail; deadline extension on exhaustion (B13).
class_name JobService
extends Node

var session: GameSession
var jobs: Dictionary = {}       # job_id -> {"rank", "xp"}
var active: Array = []          # [{"contract_id", "accepted_day", "deadline_day", "progress", "origin_y"}]
var completed: Array[String] = []


func setup(s: GameSession) -> void:
	session = s
	for id in Database.jobs:
		jobs[String(id)] = {"rank": 0, "xp": 0}


func _ready() -> void:
	EventBus.piece_fastened.connect(_on_piece_fastened)
	EventBus.item_crafted.connect(_on_item_crafted)


func _exit_tree() -> void:
	for pair in [[EventBus.piece_fastened, _on_piece_fastened], [EventBus.item_crafted, _on_item_crafted]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func rank(job_id: StringName) -> int:
	return int(jobs.get(String(job_id), {}).get("rank", 0))


func find_active(contract_id: StringName) -> Dictionary:
	for a in active:
		if a["contract_id"] == String(contract_id):
			return a
	return {}


func available(job_id: StringName) -> Array:
	return Database.contracts.values().filter(func(c): return c.job_id == job_id and c.min_rank <= rank(job_id) \
		and find_active(c.id).is_empty())


func accept_contract(contract_id: StringName) -> Result:
	var c: ContractDef = Database.contracts.get(contract_id)
	if c == null:
		return Result.failure(&"unknown")
	if not find_active(contract_id).is_empty():
		return Result.failure(&"already_active")
	if rank(c.job_id) < c.min_rank:
		return Result.failure(&"rank_too_low")
	var day := session.day()
	var a := {"contract_id": String(contract_id), "accepted_day": day, "deadline_day": day + c.days, "progress": 0, "origin_y": -1000}
	active.append(a)
	if not c.provided.is_empty():
		var tpl: MailTemplateDef = Database.mail_templates.get(&"mail_tpl_job_materials")
		var att: Array = c.provided.map(func(e): return {"type": "item", "item_id": String(e["item"]), "qty": int(e["qty"])})
		session.mail.schedule(tpl, day + 1, {"contract_id": String(contract_id), "attachments": att})
	if c.kind == &"BUILD_BLUEPRINT":
		_resolve_origin(a)
		_register_site(a)
	EventBus.contract_accepted.emit(contract_id)
	return Result.success()


func abandon_contract(contract_id: StringName) -> Result:
	var a := find_active(contract_id)
	if a.is_empty():
		return Result.failure(&"not_active")
	active.erase(a)
	EventBus.contract_abandoned.emit(contract_id)
	return Result.success()


## DELIVER_ITEMS hands items over; CRAFT_ITEMS needs the crafted count; BUILD_BLUEPRINT
## completes automatically when the last piece is fastened.
func submit_contract(contract_id: StringName) -> Result:
	var a := find_active(contract_id)
	if a.is_empty():
		return Result.failure(&"not_active")
	var c: ContractDef = Database.contracts[contract_id]
	match c.kind:
		&"DELIVER_ITEMS":
			var r := session.economy.tx.try_deliver(c.items, c.pay)
			if not r.ok:
				return r
			_complete(a, c, false)
			return Result.success()
		&"CRAFT_ITEMS":
			if int(a["progress"]) < _needed(c):
				return Result.failure(&"not_done")
		&"BUILD_BLUEPRINT":
			if not blueprint_done(a):
				return Result.failure(&"not_done")
	_complete(a, c, true)
	return Result.success()


func _needed(c: ContractDef) -> int:
	var n := 0
	for e in c.items:
		n += int(e["qty"])
	return n


func _complete(a: Dictionary, c: ContractDef, pay_now: bool) -> void:
	if pay_now:
		session.economy.tx.pay(c.pay)
	active.erase(a)
	completed.append(String(c.id))
	var job: JobDef = Database.jobs[c.job_id]
	var gained := JobModel.add_xp(job, jobs[String(c.job_id)], c.xp)
	var tpl: MailTemplateDef = Database.mail_templates.get(&"mail_tpl_job_receipt")
	if tpl:
		session.mail.schedule(tpl, session.day() + 1, {"contract_id": String(c.id), "pay": c.pay, "attachments": []})
	EventBus.contract_completed.emit(c.id, c.pay)
	if gained > 0:
		EventBus.job_rank_up.emit(c.job_id, rank(c.job_id))


## Absolute blueprint origin: site min x/z, one above the ground at the site's min corner.
func _resolve_origin(a: Dictionary) -> void:
	var c: ContractDef = Database.contracts[StringName(a["contract_id"])]
	var bp: BlueprintDef = Database.blueprints[c.blueprint]
	if SceneRouter.current_zone_id != bp.zone_id or int(a["origin_y"]) > -1000:
		return
	var w := session.terrain.world
	for y in range(bp.site_max.y, bp.site_min.y - 1, -1):
		if w.get_voxel(Vector3i(bp.site_min.x, y, bp.site_min.z)) != IVoxelWorld.AIR:
			a["origin_y"] = y + 1
			return


func blueprint_cells(a: Dictionary) -> Array:
	var c: ContractDef = Database.contracts[StringName(a["contract_id"])]
	var bp: BlueprintDef = Database.blueprints[c.blueprint]
	var origin := Vector3i(bp.site_min.x, int(a["origin_y"]), bp.site_min.z)
	return bp.pieces.map(func(p): return {"piece_id": p["piece_id"], "cell": origin + p["cell"], "rot": p["rot"]})


func blueprint_done(a: Dictionary) -> bool:
	if int(a["origin_y"]) <= -1000:
		return false
	var c: ContractDef = Database.contracts[StringName(a["contract_id"])]
	var z: StringName = Database.blueprints[c.blueprint].zone_id
	for need in blueprint_cells(a):
		var ok := false
		for inst in session.build.pieces_in(z):
			if StringName(inst["piece_id"]) == need["piece_id"] and inst["cell"] == need["cell"] \
					and int(inst["rot"]) == int(need["rot"]) and inst["state"] == BuildService.FASTENED:
				ok = true
				break
		if not ok:
			return false
	return true


func _on_piece_fastened(_uid: String) -> void:
	for a in active.duplicate():
		var c: ContractDef = Database.contracts[StringName(a["contract_id"])]
		if c.kind == &"BUILD_BLUEPRINT" and blueprint_done(a):
			_complete(a, c, true)


func _on_item_crafted(recipe_id: StringName) -> void:
	var r: RecipeDef = Database.recipes[recipe_id]
	if r.required_job != &"" and r.xp_reward > 0:
		var gained := JobModel.add_xp(Database.jobs[r.required_job], jobs[String(r.required_job)], r.xp_reward)
		if gained > 0:
			EventBus.job_rank_up.emit(r.required_job, rank(r.required_job))
	for a in active:
		var c: ContractDef = Database.contracts[StringName(a["contract_id"])]
		if c.kind == &"CRAFT_ITEMS":
			for out in r.outputs:
				for want in c.items:
					if out["item"] == want["item"]:
						a["progress"] = mini(_needed(c), int(a["progress"]) + int(out["qty"]))


## Exhaustion (spec 8.4 B13): contracts due today get one more day.
func extend_deadlines(day: int) -> void:
	for a in active:
		if int(a["deadline_day"]) <= day:
			a["deadline_day"] = day + 1


## Rollover: contracts past their deadline end without penalty.
func expire_due(day: int) -> void:
	for a in active.duplicate():
		if int(a["deadline_day"]) < day:
			active.erase(a)
			EventBus.contract_failed.emit(StringName(a["contract_id"]))


## Job sites of active BUILD_BLUEPRINT contracts in `zone_id`, as PlotDefs (build zones).
func site_plots(zone_id: StringName) -> Array:
	var out: Array = []
	for a in active:
		var c: ContractDef = Database.contracts[StringName(a["contract_id"])]
		if c.kind != &"BUILD_BLUEPRINT":
			continue
		var bp: BlueprintDef = Database.blueprints[c.blueprint]
		if zone_id != &"" and bp.zone_id != zone_id:
			continue
		var p := PlotDef.new()
		p.id = StringName("site_" + String(c.id))
		p.zone_id = bp.zone_id
		p.min_cell = bp.site_min
		p.max_cell = bp.site_max
		out.append(p)
	return out


func _register_site(a: Dictionary) -> void:
	var c: ContractDef = Database.contracts[StringName(a["contract_id"])]
	var bp: BlueprintDef = Database.blueprints[c.blueprint]
	if SceneRouter.current_zone_id == bp.zone_id:
		session.terrain.rules.add_volume(bp.site_min, bp.site_max, &"JOB_SITE")


## Zone._ready: job-site protection (9.3 P5) and origin resolution.
func bind_zone(_z: StringName) -> void:
	for a in active:
		var c: ContractDef = Database.contracts[StringName(a["contract_id"])]
		if c.kind == &"BUILD_BLUEPRINT":
			_resolve_origin(a)
			_register_site(a)


func to_dict() -> Dictionary:
	var j := {}
	for id in jobs:
		j[id] = {"rank": int(jobs[id]["rank"]), "xp": int(jobs[id]["xp"])}
	return {"jobs": j, "active_contracts": active.duplicate(true), "completed_contracts": completed.duplicate()}


func from_dict(d: Dictionary) -> void:
	for id in jobs:
		var s: Dictionary = d.get("jobs", {}).get(id, {})
		jobs[id] = {"rank": int(s.get("rank", 0)), "xp": int(s.get("xp", 0))}
	active.clear()
	for a in d.get("active_contracts", []):
		if Database.contracts.has(StringName(a["contract_id"])):
			active.append({"contract_id": String(a["contract_id"]), "accepted_day": int(a["accepted_day"]), "deadline_day": int(a["deadline_day"]),
				"progress": int(a.get("progress", 0)), "origin_y": int(a.get("origin_y", -1000))})
	completed.clear()
	for c in d.get("completed_contracts", []):
		completed.append(String(c))
