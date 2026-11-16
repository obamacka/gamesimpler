## Museum (spec 3.7): display cases, trophies with rewards, the reward letter, and geode
## contents. cases: [{"id", "category", "unlock_rule": COUNT|SET_COMPLETE, "count", "set_id"}];
## trophies: [{"id", "condition": TOTAL_COUNT|CATEGORY_COUNT|SET_COMPLETE|ALL_COMPLETE,
## "category", "set_id", "count", "reward": {"max_stamina_bonus", "coins", "unlocks": [{kind, id}]}}];
## geodes: {item_id: {"contents": [{"item", "weight"}], "undiscovered_bias_pct"}}.
class_name MuseumDef
extends Resource

@export var cases: Array = []
@export var trophies: Array = []
@export var reward_mail: StringName = &""
@export var geodes: Dictionary = {}
