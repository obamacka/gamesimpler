# P6.13: codec rules (spec 3.5).
extends GdUnitTestSuite


func _session_json() -> String:
	var s: GameSession = auto_free(GameSession.create(5))
	add_child(s)
	s.new_game()
	s.inventory.add(&"item_apple", 3)
	s.museum.model.donated["item_quartz"] = 4
	s.collection.model.mark(&"item_apple")
	return SaveCodec.encode(s.to_dict())


func test_ints_come_back_as_int() -> void:
	var r := SaveCodec.decode(_session_json())
	assert_bool(r["ok"]).is_true()
	var d: Dictionary = r["data"]
	for path in ["clock/day", "clock/minute", "wallet/coins", "player/stamina", "mail/next_mail_seq"]:
		assert_int(typeof(SaveCodec._path_get(d, path))).override_failure_message(path).is_equal(TYPE_INT)
	assert_int(typeof(d["museum"]["donated"]["item_quartz"])).is_equal(TYPE_INT)


func test_non_integral_rejected() -> void:
	var d: Dictionary = JSON.parse_string(_session_json())
	d["wallet"]["coins"] = 10.5
	assert_str(SaveCodec.decode(JSON.stringify(d))["error"]).is_equal(SaveCodec.NON_INTEGRAL)
	d["wallet"]["coins"] = 10.0
	assert_bool(SaveCodec.decode(JSON.stringify(d))["ok"]).is_true()


func test_vectors_are_arrays() -> void:
	var d: Dictionary = JSON.parse_string(_session_json())
	assert_bool(d["player"]["position"] is Array).is_true()
	assert_int(d["player"]["position"].size()).is_equal(3)


func test_sanitization() -> void:
	var d: Dictionary = JSON.parse_string(_session_json())
	d["collection"]["discovered"] = ["item_apple", "item_apple", "item_removed_thing"]
	d["museum"]["donated"]["item_removed_thing"] = 2
	d["inventory"]["backpack"][5] = {"item_id": "item_removed_thing", "qty": 1}
	var r := SaveCodec.decode(JSON.stringify(d))
	assert_bool(r["ok"]).is_true()
	assert_array(r["data"]["collection"]["discovered"]).is_equal(["item_apple", "item_quartz"])   # deduped, donated added, unknown dropped
	assert_bool(r["data"]["museum"]["donated"].has("item_removed_thing")).is_false()
	assert_object(r["data"]["inventory"]["backpack"][5]).is_null()
	assert_array(r["notices"]).contains([&"unknown_ids_dropped"])


func test_structural_failure() -> void:
	var d: Dictionary = JSON.parse_string(_session_json())
	d["museum"]["donated"] = ["item_quartz"]
	assert_str(SaveCodec.decode(JSON.stringify(d))["error"]).is_equal(SaveCodec.STRUCTURAL)
	d = JSON.parse_string(_session_json())
	d["pets"] = {}
	assert_str(SaveCodec.decode(JSON.stringify(d))["error"]).is_equal(SaveCodec.STRUCTURAL)
	assert_str(SaveCodec.decode("{not json")["error"]).is_equal(SaveCodec.PARSE)


func test_encoding_is_deterministic() -> void:
	var s: GameSession = auto_free(GameSession.create(5))
	add_child(s)
	s.new_game()
	assert_str(SaveCodec.encode(s.to_dict())).is_equal(SaveCodec.encode(s.to_dict()))
