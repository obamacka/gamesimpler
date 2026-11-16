# P6.12: discovery once per collectible; geode bias.
extends GdUnitTestSuite


func test_mark_once_and_only_collectibles() -> void:
	var c := CollectionModel.new()
	assert_bool(c.mark(&"item_apple")).is_true()
	assert_bool(c.mark(&"item_apple")).is_false()
	assert_bool(c.mark(&"item_wood")).is_false()
	assert_dict(c.to_dict()).is_equal({"discovered": ["item_apple"]})


func test_geode_prefers_undiscovered() -> void:
	var c := CollectionModel.new()
	for id in [&"item_quartz", &"item_amethyst", &"item_agate", &"item_jasper"]:
		c.mark(id)
	var rng := RngStreams.new(77)
	var topaz := 0
	for i in 400:
		if GeodeModel.open(&"item_geode", c, rng) == &"item_topaz":
			topaz += 1
	# topaz weight 5 of 95; doubled while undiscovered -> about 10 of 100 (vs about 5 unbiased)
	assert_int(topaz).is_between(24, 60)
	assert_str(GeodeModel.open(&"item_wood", c, rng)).is_equal(&"")
