# P2B.12: FarmModel rules (spec 10.2, 10.5, D20 to D23). Zone "z"; soil at y 0, crops at y 1.
extends GdUnitTestSuite

const Z := &"z"
const SOIL := Vector3i(2, 0, 3)
const CROP := Vector3i(2, 1, 3)

var m: FarmModel


func before_test() -> void:
	m = FarmModel.new()
	m.configure(Database.farm)


func _crops() -> Dictionary:
	return Database.crops


func _plant(crop: StringName, day: int, soil: Vector3i = SOIL) -> void:
	m.mark_tilled(Z, soil)
	m.plant(Z, soil, crop, day)


func test_farmable_rule() -> void:
	assert_str(FarmModel.farmable_reason(&"mat_grass", 2, true, false)).is_equal(&"")
	assert_str(FarmModel.farmable_reason(&"mat_dirt", 3, true, false)).is_equal(&"")
	assert_str(FarmModel.farmable_reason(&"mat_grass", 2, false, false)).is_equal(FarmModel.NOT_FARMABLE)
	assert_str(FarmModel.farmable_reason(&"mat_grass", 2, true, true)).is_equal(FarmModel.PROTECTED)
	assert_str(FarmModel.farmable_reason(&"mat_stone", 2, true, false)).is_equal(FarmModel.NOT_SOIL)
	assert_str(FarmModel.farmable_reason(&"mat_grass", 0, true, false)).is_equal(FarmModel.NO_ROOM)   # not top-exposed
	assert_str(FarmModel.farmable_reason(&"mat_grass", 1, true, false)).is_equal(FarmModel.NO_ROOM)


func test_plant_needs_farmland_and_free_cell() -> void:
	assert_str(m.can_plant(Z, SOIL)).is_equal(FarmModel.NOT_TILLED)
	m.mark_tilled(Z, SOIL)
	assert_str(m.can_plant(Z, SOIL)).is_equal(&"")
	m.plant(Z, SOIL, &"crop_carrot", 3)
	assert_str(m.can_plant(Z, SOIL)).is_equal(FarmModel.OCCUPIED)
	assert_dict(m.crop_at(Z, CROP)).contains_key_value("crop_id", "crop_carrot")


func test_growth_only_when_watered_previous_day() -> void:
	_plant(&"crop_carrot", 3)
	assert_str(m.water(Z, SOIL, 3)).is_equal(&"")   # same-day plant and water counts
	m.daily_growth(4, _crops())
	assert_int(m.crop_at(Z, CROP)["growth_days"]).is_equal(1)
	m.daily_growth(5, _crops())   # not watered on day 4
	assert_int(m.crop_at(Z, CROP)["growth_days"]).is_equal(1)
	m.water(Z, SOIL, 6)
	m.daily_growth(8, _crops())   # watered day 6, rollover to 8 skips day 7: no growth
	assert_int(m.crop_at(Z, CROP)["growth_days"]).is_equal(1)


func test_stage_boundaries_follow_days_per_stage() -> void:
	_plant(&"crop_pumpkin", 1)   # [1, 1, 1, 1, 2]
	var reported: Array = []
	for day in range(1, 8):
		m.water(Z, SOIL, day)
		for g in m.daily_growth(day + 1, _crops()):
			reported.append([day + 1, g["stage"]])
	var def: CropDef = _crops()[&"crop_pumpkin"]
	assert_int(def.stage_count()).is_equal(5)
	assert_array(reported).contains_exactly([[2, 1], [3, 2], [4, 3], [5, 4], [7, 5]])   # day 6: still stage 4
	assert_bool(def.is_ripe(m.crop_at(Z, CROP)["growth_days"])).is_true()


func test_unwatered_never_dies() -> void:
	_plant(&"crop_carrot", 1)
	m.water(Z, SOIL, 1)
	m.daily_growth(2, _crops())
	for day in range(3, 40):
		m.daily_growth(day, _crops())
	var c := m.crop_at(Z, CROP)
	assert_bool(c.is_empty()).is_false()
	assert_int(c["growth_days"]).is_equal(1)
	assert_array(c.keys()).not_contains(["wilted", "dead"])


func test_ripe_stays_ripe() -> void:
	_plant(&"crop_carrot", 1)
	for day in range(1, 10):
		m.water(Z, SOIL, day)
		m.daily_growth(day + 1, _crops())
	var def: CropDef = _crops()[&"crop_carrot"]
	assert_int(m.crop_at(Z, CROP)["growth_days"]).is_equal(def.days_to_ripe())
	assert_bool(def.is_ripe(m.crop_at(Z, CROP)["growth_days"])).is_true()


func _ripe(crop: StringName) -> void:
	var def: CropDef = _crops()[crop]
	_plant(crop, 1)
	m.crops[FarmModel.key(Z, CROP)]["growth_days"] = def.days_to_ripe()


func test_harvest_deterministic_for_seed() -> void:
	var results: Array = []
	for i in 2:
		m = FarmModel.new()
		_ripe(&"crop_carrot")
		results.append(m.harvest(Z, CROP, _crops()[&"crop_carrot"], RngStreams.new(4242)))
	assert_dict(results[0]).is_equal(results[1])
	var def: CropDef = _crops()[&"crop_carrot"]
	assert_bool(results[0]["ok"]).is_true()
	assert_int(results[0]["qty"]).is_between(def.yield_min, def.yield_max)
	assert_bool(m.crop_at(Z, CROP).is_empty()).is_true()   # single harvest leaves empty farmland
	assert_bool(m.is_tilled(Z, SOIL)).is_true()


func test_harvest_unripe_refused() -> void:
	_plant(&"crop_carrot", 1)
	var r := m.harvest(Z, CROP, _crops()[&"crop_carrot"], RngStreams.new(1))
	assert_str(r["reason"]).is_equal(FarmModel.NOT_RIPE)
	assert_str(m.harvest(Z, Vector3i(9, 9, 9), _crops()[&"crop_carrot"], RngStreams.new(1))["reason"]).is_equal(FarmModel.NO_CROP)


func test_regrow_returns_to_regrow_stage() -> void:
	_ripe(&"crop_strawberry")
	var def: CropDef = _crops()[&"crop_strawberry"]
	assert_bool(m.harvest(Z, CROP, def, RngStreams.new(1))["ok"]).is_true()
	var c := m.crop_at(Z, CROP)
	assert_int(def.stage_for(c["growth_days"])).is_equal(def.regrow_stage)
	assert_int(c["harvests"]).is_equal(1)


func test_watering_twice_spends_once_and_can_refills() -> void:
	m.mark_tilled(Z, SOIL)
	assert_str(m.water(Z, SOIL, 3)).is_equal(&"")
	assert_str(m.water(Z, SOIL, 3)).is_equal(FarmModel.ALREADY)
	assert_int(m.can_water).is_equal(19)
	assert_str(m.water(Z, Vector3i(50, 0, 50), 3)).is_equal(FarmModel.NOT_TILLED)
	m.can_water = 0
	m.mark_tilled(Z, SOIL + Vector3i.RIGHT)
	assert_str(m.water(Z, SOIL + Vector3i.RIGHT, 3)).is_equal(FarmModel.EMPTY_CAN)
	m.refill()
	assert_int(m.can_water).is_equal(20)


func test_sprinkler_waters_eight_neighbors() -> void:
	m.place_sprinkler(Z, CROP)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx != 0 or dz != 0:
				_plant(&"crop_carrot", 1, SOIL + Vector3i(dx, 0, dz))
	_plant(&"crop_carrot", 1, SOIL + Vector3i(2, 0, 0))   # outside radius 1
	var grew := m.daily_growth(2, _crops())
	assert_int(grew.size()).is_equal(8)
	assert_int(m.crop_at(Z, CROP + Vector3i(2, 0, 0))["growth_days"]).is_equal(0)


func test_untill_clears_wetness() -> void:
	m.mark_tilled(Z, SOIL)
	m.water(Z, SOIL, 2)
	m.untill(Z, SOIL)
	assert_bool(m.is_tilled(Z, SOIL)).is_false()
	assert_bool(m.is_watered_today(Z, SOIL, 2)).is_false()


func test_json_round_trip_keeps_ints() -> void:
	_plant(&"crop_carrot", 3)
	m.water(Z, SOIL, 3)
	m.place_sprinkler(Z, Vector3i(5, 1, 5))
	var d := m.to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d))
	var b := FarmModel.new()
	b.from_dict(parsed)
	assert_dict(b.to_dict()).is_equal(d)
	var c: Dictionary = b.crops[FarmModel.key(Z, CROP)]
	for k in ["growth_days", "planted_day", "harvests"]:
		assert_int(typeof(c[k])).is_equal(TYPE_INT)
	assert_int(typeof(b.wet[FarmModel.key(Z, SOIL)])).is_equal(TYPE_INT)
	assert_int(typeof(b.can_water)).is_equal(TYPE_INT)
