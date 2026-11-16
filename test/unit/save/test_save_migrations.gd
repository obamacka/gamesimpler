# P6.13: migrations apply in order, are idempotent, and lift a v1 fixture to the current
# version.
extends GdUnitTestSuite

const V1 := {"schema_version": 1, "clock": {"day": 7, "minute": 400}, "wallet": {"coins": 12},
	"player": {"stamina": 80, "max_stamina_bonus": 0, "home": {"zone_id": "zone_starter_cabin", "bed_key": "bed_01"}},
	"inventory": {"backpack": [{"item_id": "item_apple", "qty": 2}]}, "mail": {"next_mail_seq": 3, "inbox": [], "scheduled": []}}


func test_v1_fixture_to_current() -> void:
	var r := SaveCodec.decode(JSON.stringify(V1))
	assert_bool(r["ok"]).is_true()
	var d: Dictionary = r["data"]
	assert_int(d["schema_version"]).is_equal(SaveCodec.CURRENT)
	assert_dict(d["museum"]).contains_keys(["donated", "rewards_granted"])
	assert_dict(d["collection"]).is_equal({"discovered": []})
	assert_str(d["player"]["zone_id"]).is_equal(String(Database.home_zone))
	var s: GameSession = auto_free(GameSession.create(1))
	add_child(s)
	s.from_dict(d)
	assert_int(s.wallet.model.coins).is_equal(12)
	assert_int(s.inventory.count(&"item_apple")).is_equal(2)


func test_idempotent_and_ordered() -> void:
	var once := SaveCodec.migrate(V1.duplicate(true))
	var twice := SaveCodec.migrate(once.duplicate(true))
	assert_dict(twice).is_equal(once)
	assert_bool(SaveCodec.MIGRATIONS.has(1)).is_true()
	var newer := {"schema_version": SaveCodec.CURRENT + 1}
	assert_str(SaveCodec.decode(JSON.stringify(newer))["error"]).is_equal(SaveCodec.TOO_NEW)
