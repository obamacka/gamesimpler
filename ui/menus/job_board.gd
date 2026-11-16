## Job board (spec 5.8): available contracts to accept, active ones to submit or abandon.
## args: {"job_id"} (empty = all jobs).
extends MenuBase

var job_id: StringName


func build() -> void:
	job_id = StringName(args.get("job_id", ""))
	make_list("Job board", Vector2(720, 500))
	refresh()


func refresh() -> void:
	var s := GameSession.current
	clear_rows()
	for a in s.jobs.active:
		var id := StringName(a["contract_id"])
		var c: ContractDef = Database.contracts[id]
		if job_id != &"" and c.job_id != job_id:
			continue
		add_row("Hand in: %s (due day %d)" % [String(id).trim_prefix("contract_"), a["deadline_day"]], Color(0.5, 0.8, 0.5), func(): submit(id))
		add_row("Give up: %s" % String(id).trim_prefix("contract_"), Color(0.8, 0.5, 0.4), func(): abandon(id))
	var jobs_list: Array = Database.jobs.keys() if job_id == &"" else [job_id]
	for j in jobs_list:
		for c in s.jobs.available(j):
			var cid: StringName = c.id
			add_row("Take: %s  pays %d" % [String(cid).trim_prefix("contract_"), c.pay], Color(0.6, 0.7, 0.9), func(): accept(cid))


func initial_focus() -> Control:
	return first_enabled()


func accept(id: StringName) -> Result:
	var r := GameSession.current.jobs.accept_contract(id)
	say("Accepted! Materials arrive by mail tomorrow." if r.ok else String(r.error))
	refresh()
	return r


func submit(id: StringName) -> Result:
	var r := GameSession.current.jobs.submit_contract(id)
	say("Great job!" if r.ok else ("Not finished yet" if r.error == &"not_done" else String(r.error)))
	refresh()
	return r


func abandon(id: StringName) -> Result:
	var r := GameSession.current.jobs.abandon_contract(id)
	refresh()
	return r
