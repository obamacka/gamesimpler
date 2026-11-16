# P2.27: focused-target scoring and aim override (spec 4.5).
extends GdUnitTestSuite


func _c(key: String, kind: StringName, distance: float, facing: float, aimed := false) -> Dictionary:
	return {"key": key, "kind": kind, "distance": distance, "facing_dot": facing, "aimed": aimed}


func test_aim_wins() -> void:
	var r := InteractionResolver.best([_c("pickup", &"PICKUP", 0.5, 1.0), _c("tree", &"FORAGE", 2.0, 0.0, true)])
	assert_str(r["key"]).is_equal("tree")


func test_score_prefers_facing_close_and_priority() -> void:
	assert_str(InteractionResolver.best([_c("a", &"FORAGE", 1.0, 1.0), _c("b", &"FORAGE", 1.0, 0.2)])["key"]).is_equal("a")
	assert_str(InteractionResolver.best([_c("a", &"FORAGE", 1.0, 1.0), _c("b", &"PICKUP", 1.0, 1.0)])["key"]).is_equal("b")
	assert_str(InteractionResolver.best([_c("b", &"FORAGE", 1.0, 1.0), _c("a", &"FORAGE", 1.0, 1.0)])["key"]).is_equal("a")


func test_empty() -> void:
	assert_dict(InteractionResolver.best([])).is_empty()
