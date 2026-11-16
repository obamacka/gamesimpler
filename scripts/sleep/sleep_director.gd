## Sleep transitions for bed, late night and exhaustion, plus Go Home and safe-ground returns
## (spec 6.2, 6.3). Runs while the tree is paused (PROCESS_MODE_ALWAYS).
class_name SleepDirector
extends Node

var session: GameSession
var busy := false


func setup(s: GameSession) -> void:
	session = s
	process_mode = Node.PROCESS_MODE_ALWAYS


func begin_sleep(reason: StringName) -> void:
	if busy:
		push_warning("SleepDirector: sleep already in progress, ignoring %s" % reason)
		return
	busy = true
	if SceneRouter.busy:
		await EventBus.zone_loaded   # spec 6.2: exhaustion during a zone transition waits for it
	EventBus.sleep_transition_started.emit(reason)
	PauseManager.request_pause(PauseManager.TRANSITION)
	await SceneRouter.fade_out()
	var new_day := session.day() + 1
	_schedule_care_letter(reason, new_day)
	if reason == &"exhausted":
		session.exhaustion["count_total"] = int(session.exhaustion["count_total"]) + 1
		session.jobs.extend_deadlines(new_day - 1)   # spec 8.4 B13
	session.rollover.run(new_day)
	await SceneRouter.change_zone(session.housing.home_zone, session.housing.home_bed_key)
	session.stamina.refill()
	SaveService.autosave(session)
	await SceneRouter.fade_in()
	EventBus.player_woke.emit(reason, new_day)
	PauseManager.release_pause(PauseManager.TRANSITION)
	busy = false


func _schedule_care_letter(reason: StringName, new_day: int) -> void:
	var pool := CareLetterModel.pool_for(reason, new_day - 1, int(session.exhaustion["last_snack_day"]))
	if pool == &"":
		return
	var tpl := CareLetterModel.pick(Database.templates_in_pool(pool), session.rng)
	if tpl == null:
		return
	var params := {"reason": String(reason)}
	var friend := session.npcs.best_friend()
	if friend != &"":
		params["sender_id"] = String(friend)   # spec P5.2: the closest friend sends the care letter
	session.mail.schedule(tpl, new_day, params)
	if tpl.has_snack:
		session.exhaustion["last_snack_day"] = new_day


## Go Home (D19): no time skip, no cost.
func go_home() -> void:
	if busy:
		return
	busy = true
	PauseManager.request_pause(PauseManager.TRANSITION)
	await SceneRouter.fade_out()
	await SceneRouter.change_zone(session.housing.home_zone, session.housing.home_bed_key)
	await SceneRouter.fade_in()
	EventBus.player_sent_home.emit()
	PauseManager.release_pause(PauseManager.TRANSITION)
	busy = false


## SafeGround (spec 6.3): quick fade and return to the last safe position, no cost.
func return_to_safe(body: Node3D, position: Vector3) -> void:
	if busy:
		return
	busy = true
	PauseManager.request_pause(PauseManager.TRANSITION)
	await SceneRouter.fade_out(0.2)
	body.global_position = position
	if body is CharacterBody3D:
		body.velocity = Vector3.ZERO
	await SceneRouter.fade_in(0.2)
	EventBus.player_returned_to_safe_ground.emit()
	PauseManager.release_pause(PauseManager.TRANSITION)
	busy = false
