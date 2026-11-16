# P2B.14: the session `farm` section and hotbar survive a JSON text round trip (spec 3.5).
extends GdUnitTestSuite


func _session(seed_value: int) -> GameSession:
	var s := GameSession.create(seed_value)
	add_child(s)
	return auto_free(s)


func test_farm_section_round_trip() -> void:
	var a := _session(5)
	a.new_game()
	var m := a.farm.model
	m.mark_tilled(&"zone_home_meadow", Vector3i(4, 2, 0))
	m.mark_tilled(&"zone_home_meadow", Vector3i(5, 2, 0))
	m.plant(&"zone_home_meadow", Vector3i(4, 2, 0), &"crop_strawberry", 3)
	m.crops[FarmModel.key(&"zone_home_meadow", Vector3i(4, 3, 0))]["growth_days"] = 3
	m.water(&"zone_home_meadow", Vector3i(4, 2, 0), 3)
	m.place_sprinkler(&"zone_home_meadow", Vector3i(6, 3, 0))
	a.hotbar.refs[1] = null
	a.hotbar.select(3)
	var d := a.to_dict()
	assert_dict(d).contains_keys(["farm"])
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d))
	var b := _session(1)
	b.from_dict(parsed)
	assert_dict(b.farm.to_dict()).is_equal(a.farm.to_dict())
	assert_int(b.hotbar.selected).is_equal(3)
	assert_array(b.hotbar.refs).is_equal(a.hotbar.refs)
	assert_int(typeof(b.hotbar.refs[0])).is_equal(TYPE_INT)
	var crop: Dictionary = b.farm.model.crops.values()[0]
	assert_int(typeof(crop["growth_days"])).is_equal(TYPE_INT)
	assert_int(typeof(b.farm.model.can_water)).is_equal(TYPE_INT)
	assert_dict(b.to_dict()["farm"]).is_equal(d["farm"])


func test_missing_farm_section_loads_defaults() -> void:
	var b := _session(1)
	b.from_dict({})
	assert_dict(b.farm.model.crops).is_empty()
	assert_int(b.farm.model.can_water).is_equal(Database.farm.can_capacity)
