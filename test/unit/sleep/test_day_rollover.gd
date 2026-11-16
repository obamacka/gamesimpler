# P2.27: rollover runs steps in spec order regardless of registration order; clock rules.
extends GdUnitTestSuite


func test_order_is_fixed_and_unregistered_steps_skipped() -> void:
	var r := DayRollover.new()
	var calls: Array = []
	for step in [&"day_started", &"mail_deliver", &"clock", &"terrain_reset", &"world_respawn"]:
		r.register(step, func(day): calls.append([step, day]))
	r.run(6)
	assert_array(calls.map(func(c): return c[0])).contains_exactly([&"clock", &"world_respawn", &"terrain_reset", &"mail_deliver", &"day_started"])
	assert_bool(calls.all(func(c): return c[1] == 6)).is_true()
	assert_array(r.last_run).contains_exactly([&"clock", &"world_respawn", &"terrain_reset", &"mail_deliver", &"day_started"])


func test_mail_before_day_started() -> void:
	assert_int(DayRollover.ORDER.find(&"mail_deliver")).is_less(DayRollover.ORDER.find(&"day_started"))
	assert_int(DayRollover.ORDER.find(&"farm_growth")).is_greater(DayRollover.ORDER.find(&"terrain_reset"))


func test_clock_late_night_fires_once() -> void:
	var c := GameClockModel.new()
	c.set_time(5, GameClockModel.LATE_NIGHT - 2)
	assert_bool(c.tick(1.0)).is_false()
	assert_bool(c.tick(1.0)).is_true()
	assert_bool(c.tick(5.0)).is_false()
	c.set_morning(6)
	assert_int(c.minute).is_equal(360)
	assert_int(c.day).is_equal(6)


func test_clock_one_game_minute_per_second() -> void:
	var c := GameClockModel.new()
	c.set_time(1, 600)
	for i in 60:
		c.tick(1.0 / 60.0)
	assert_int(c.minute).is_equal(601)


func test_clock_round_trip() -> void:
	var c := GameClockModel.new()
	c.set_time(14, 545)
	var c2 := GameClockModel.new()
	c2.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_int(c2.day).is_equal(14)
	assert_int(c2.minute).is_equal(545)


# P2B.14: the session registers farm growth as step 4, after terrain reset and before mail.
func test_session_farm_growth_step_order() -> void:
	var s: GameSession = auto_free(GameSession.create(3))
	add_child(s)
	s.rollover.run(6)
	assert_int(DayRollover.ORDER.find(&"farm_growth")).is_equal(3)
	var run := s.rollover.last_run
	assert_int(run.find(&"farm_growth")).is_greater(run.find(&"terrain_reset"))
	assert_int(run.find(&"farm_growth")).is_less(run.find(&"mail_deliver"))
	assert_int(run.find(&"terrain_reset")).is_greater_equal(0)
