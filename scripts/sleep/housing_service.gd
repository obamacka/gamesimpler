## Home bed (spec D10). Phase 4 adds plots and deeds.
class_name HousingService
extends Node

var home_zone: StringName
var home_bed_key: StringName


func _ready() -> void:
	if home_zone == &"":
		home_zone = Database.home_zone
		home_bed_key = Database.home_bed_key


func set_home_bed(zone_id: StringName, bed_key: StringName) -> void:
	home_zone = zone_id
	home_bed_key = bed_key


func to_dict() -> Dictionary:
	return {"zone_id": String(home_zone), "bed_key": String(home_bed_key)}


func from_dict(d: Dictionary) -> void:
	home_zone = StringName(d.get("zone_id", Database.home_zone))
	home_bed_key = StringName(d.get("bed_key", Database.home_bed_key))
