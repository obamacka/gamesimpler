# Deterministic RNG streams independent across names.
extends GdUnitTestSuite


func test_same_seed_same_sequence() -> void:
	var a := RngStreams.new(5)
	var b := RngStreams.new(5)
	for i in 10:
		assert_int(a.randi_range("loot", 0, 1000)).is_equal(b.randi_range("loot", 0, 1000))


func test_streams_independent_of_interleaving() -> void:
	var a := RngStreams.new(5)
	var b := RngStreams.new(5)
	var x := a.randi_range("loot", 0, 1000)
	b.randi_range("mail_pool", 0, 1000)
	assert_int(b.randi_range("loot", 0, 1000)).is_equal(x)


func test_round_trip_continues_sequence() -> void:
	var a := RngStreams.new(5)
	a.randi_range("loot", 0, 9)
	var b := RngStreams.new()
	b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_int(b.randi_range("loot", 0, 100000)).is_equal(a.randi_range("loot", 0, 100000))


func test_weighted_index_bounds() -> void:
	var r := RngStreams.new(1)
	for i in 50:
		assert_int(r.weighted_index("w", [0, 3, 0])).is_equal(1)
	assert_int(r.weighted_index("w", [0, 0])).is_equal(-1)
