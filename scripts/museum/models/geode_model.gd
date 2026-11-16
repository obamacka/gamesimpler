## Geode opening (spec 6.4): weighted draw with undiscovered entries boosted by
## undiscovered_bias_pct (default 200 = twice as likely). Pure.
class_name GeodeModel
extends RefCounted


static func open(geode_item: StringName, collection: CollectionModel, rng: RngStreams) -> StringName:
	var g: Dictionary = Database.museum.geodes.get(geode_item, {})
	var contents: Array = g.get("contents", [])
	if contents.is_empty():
		return &""
	var bias := int(g.get("undiscovered_bias_pct", 200))
	var weights: Array = contents.map(func(c): return int(c["weight"]) * (bias if not collection.is_discovered(c["item"]) else 100))
	return contents[rng.weighted_index("discovery", weights)]["item"]
