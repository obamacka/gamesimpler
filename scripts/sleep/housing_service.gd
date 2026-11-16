## Home bed (spec D10) and plot deeds (spec 1.8). Phase 4 adds purchase through the
## TransactionCoordinator; Phase 3 grants the test plot with a debug command.
class_name HousingService
extends Node

var home_zone: StringName
var home_bed_key: StringName
var owned_plots: Array[StringName] = []


func _ready() -> void:
	if home_zone == &"":
		home_zone = Database.home_zone
		home_bed_key = Database.home_bed_key


func set_home_bed(zone_id: StringName, bed_key: StringName) -> void:
	home_zone = zone_id
	home_bed_key = bed_key
	EventBus.home_changed.emit(zone_id, bed_key)


func grant_deed(plot_id: StringName) -> bool:
	if not Database.plots.has(plot_id) or owns(plot_id):
		return false
	owned_plots.append(plot_id)
	EventBus.deed_granted.emit(plot_id)
	return true


func owns(plot_id: StringName) -> bool:
	var p: PlotDef = Database.plots.get(plot_id)
	return p != null and (p.owned_from_start or plot_id in owned_plots)


## Owned PlotDefs in `zone_id` (all zones when empty).
func owned_plot_defs(zone_id: StringName = &"") -> Array:
	return Database.plots.values().filter(func(p): return owns(p.id) and (zone_id == &"" or p.zone_id == zone_id))


func plot_at(zone_id: StringName, cell: Vector3i) -> PlotDef:
	for p in owned_plot_defs(zone_id):
		if p.contains(zone_id, cell):
			return p
	return null


func to_dict() -> Dictionary:
	return {"zone_id": String(home_zone), "bed_key": String(home_bed_key)}


func plots_to_dict() -> Dictionary:
	var a: Array = owned_plots.map(func(p): return String(p))
	a.sort()
	return {"owned_plots": a}


func from_dict(d: Dictionary) -> void:
	home_zone = StringName(d.get("zone_id", Database.home_zone))
	home_bed_key = StringName(d.get("bed_key", Database.home_bed_key))


func plots_from_dict(d: Dictionary) -> void:
	owned_plots.clear()
	for p in d.get("owned_plots", []):
		if Database.plots.has(StringName(p)):
			owned_plots.append(StringName(p))
