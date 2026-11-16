# P2.25: stamina clamp, edge-triggered depletion, last action lands, thresholds once per day.
extends GdUnitTestSuite


func test_clamp_and_edge() -> void:
	var s := StaminaModel.new()
	s.current = 1
	var r := s.spend(2)
	assert_int(s.current).is_equal(0)
	assert_bool(r["depleted_now"]).is_true()
	assert_int(r["spent"]).is_equal(1)
	var r2 := s.spend(2)
	assert_bool(r2["depleted_now"]).is_false()
	assert_int(r2["spent"]).is_equal(0)
	assert_bool(s.can_act()).is_false()


func test_thresholds_once_per_day() -> void:
	var s := StaminaModel.new()
	var r := s.spend(75)
	assert_array(r["low_crossed"]).contains_exactly([25])
	assert_array(s.spend(15)["low_crossed"]).contains_exactly([10])
	s.restore(50)
	assert_array(s.spend(50)["low_crossed"]).is_empty()
	s.new_day()
	s.refill()
	assert_array(s.spend(92)["low_crossed"]).contains_exactly([25, 10])


func test_refill_includes_bonus_capped() -> void:
	var s := StaminaModel.new()
	s.bonus = 70
	s.refill()
	assert_int(s.current).is_equal(150)


func test_restore_clamps() -> void:
	var s := StaminaModel.new()
	s.current = 95
	assert_int(s.restore(30)).is_equal(5)


func test_round_trip() -> void:
	var s := StaminaModel.new()
	s.bonus = 10
	s.current = 82
	var s2 := StaminaModel.new()
	s2.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_int(s2.current).is_equal(82)
	assert_int(s2.bonus).is_equal(10)
	assert_int(typeof(s2.current)).is_equal(TYPE_INT)
