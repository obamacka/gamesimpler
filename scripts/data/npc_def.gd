## NPC (spec 3.4). schedule: [{"from": minute, "marker": StringName}]; gift_prefs: loved,
## liked, disliked item id lists; dialogue: {"greeting": [...], "chat": [...]}.
class_name NpcDef
extends Resource

@export var id: StringName
@export var name_key := ""
@export var color := Color.WHITE
@export var shop_id: StringName = &""
@export var job_id: StringName = &""
@export var is_curator := false
@export var gift_prefs: Dictionary = {}
@export var schedule: Array = []
@export var dialogue: Dictionary = {}


func preference(item_id: StringName) -> StringName:
	for k in ["loved", "liked", "disliked"]:
		if item_id in gift_prefs.get(k, []):
			return StringName(k)
	return &"neutral"


## The schedule marker for `minute` (latest entry whose start has passed; before the first
## entry of the day, the last entry still applies).
func marker_at(minute: int) -> StringName:
	if schedule.is_empty():
		return &""
	var m: StringName = schedule.back()["marker"]
	for e in schedule:
		if minute >= int(e["from"]):
			m = e["marker"]
	return m
