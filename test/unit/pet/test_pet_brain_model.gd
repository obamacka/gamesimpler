# P5.14: every pet transition of spec 4.6 at its threshold boundary.
extends GdUnitTestSuite

const DT := 0.1
var m: PetBrainModel


func before_test() -> void:
	m = PetBrainModel.new()
	m.configure(Database.pet_species[&"pet_dog"], Database.pet_config)   # follow 2.5, teleport 20, idle 2, wander 6


func _f(extra: Dictionary = {}) -> Dictionary:
	var f := {"dist": 1.0, "player_moving": false, "has_path": true, "fed_today": true, "bed_dist": INF}
	f.merge(extra, true)
	return f


func _run(seconds: float, extra: Dictionary = {}) -> StringName:
	var st := m.state
	for i in int(round(seconds / DT)):
		st = m.update(DT, _f(extra))
	return st


func test_idle_after_two_seconds_within_follow_distance() -> void:
	assert_str(_run(1.9)).is_equal(PetBrainModel.FOLLOW)
	assert_str(_run(0.2)).is_equal(PetBrainModel.IDLE)


func test_no_idle_when_far() -> void:
	assert_str(_run(3.0, {"dist": 2.6})).is_equal(PetBrainModel.FOLLOW)


func test_wander_after_six_seconds_and_back_to_follow() -> void:
	_run(2.1)
	assert_str(_run(3.8)).is_equal(PetBrainModel.IDLE)   # 5.9 s idle
	assert_str(_run(0.2)).is_equal(PetBrainModel.WANDER)
	assert_str(m.update(DT, _f({"dist": 6.1}))).is_equal(PetBrainModel.FOLLOW)
	_run(6.5)
	assert_str(m.state).is_equal(PetBrainModel.WANDER)
	assert_str(m.update(DT, _f({"player_moving": true}))).is_equal(PetBrainModel.FOLLOW)


func test_idle_to_follow_when_player_moves() -> void:
	_run(2.1)
	assert_str(m.update(DT, _f({"player_moving": true}))).is_equal(PetBrainModel.FOLLOW)


func test_teleport_far_no_path_or_zone_change() -> void:
	assert_str(m.update(DT, _f({"dist": 20.0}))).is_equal(PetBrainModel.FOLLOW)
	assert_str(m.update(DT, _f({"dist": 20.1}))).is_equal(PetBrainModel.TELEPORT)
	assert_str(m.update(DT, _f())).is_equal(PetBrainModel.FOLLOW)
	assert_str(_run(1.9, {"has_path": false, "player_moving": true, "dist": 5.0})).is_equal(PetBrainModel.FOLLOW)
	assert_str(_run(0.1, {"has_path": false, "player_moving": true, "dist": 5.0})).is_equal(PetBrainModel.TELEPORT)
	m.update(DT, _f())
	_run(2.1)
	assert_str(m.update(DT, _f({"zone_changed": true}))).is_equal(PetBrainModel.TELEPORT)


func test_react_on_emote_or_pat() -> void:
	assert_str(m.update(DT, _f({"emote": true}))).is_equal(PetBrainModel.REACT)
	assert_str(_run(1.3)).is_equal(PetBrainModel.REACT)
	assert_str(_run(0.2)).is_equal(PetBrainModel.FOLLOW)
	_run(2.1)
	assert_str(m.update(DT, _f({"pat": true}))).is_equal(PetBrainModel.REACT)


func test_eat_on_feed() -> void:
	assert_str(m.update(DT, _f({"feed": true}))).is_equal(PetBrainModel.EAT)
	assert_str(_run(1.8)).is_equal(PetBrainModel.EAT)
	assert_str(_run(0.2)).is_equal(PetBrainModel.FOLLOW)


func test_go_to_bowl_when_food_and_not_fed() -> void:
	_run(2.1)
	assert_str(m.update(DT, _f({"bowl_food": true, "fed_today": true}))).is_equal(PetBrainModel.IDLE)
	assert_str(m.update(DT, _f({"bowl_food": true, "fed_today": false}))).is_equal(PetBrainModel.GO_TO_BOWL)
	assert_str(m.update(DT, _f({"reached": true}))).is_equal(PetBrainModel.EAT)


func test_nap_near_bed_while_player_rests() -> void:
	_run(2.1)
	assert_str(m.update(DT, _f({"player_resting": true, "bed_dist": 10.1}))).is_equal(PetBrainModel.IDLE)
	assert_str(m.update(DT, _f({"player_resting": true, "bed_dist": 10.0}))).is_equal(PetBrainModel.NAP)
	assert_str(m.update(DT, _f({"player_moving": true}))).is_equal(PetBrainModel.FOLLOW)


func test_call_reaches_or_teleports() -> void:
	assert_str(m.update(DT, _f({"call": true, "dist": 5.0}))).is_equal(PetBrainModel.CALL)
	assert_str(m.update(DT, _f({"reached": true}))).is_equal(PetBrainModel.FOLLOW)
	m.update(DT, _f({"call": true, "dist": 5.0}))
	assert_str(_run(0.9, {"has_path": false, "dist": 5.0})).is_equal(PetBrainModel.CALL)
	assert_str(_run(0.1, {"has_path": false, "dist": 5.0})).is_equal(PetBrainModel.TELEPORT)
	m.update(DT, _f())
	m.update(DT, _f({"call": true, "dist": 5.0}))
	assert_str(m.update(DT, _f({"dist": 10.1}))).is_equal(PetBrainModel.TELEPORT)
