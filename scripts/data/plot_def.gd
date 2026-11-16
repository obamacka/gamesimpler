## Land plot (spec 3.4). Phase 2B: farmable area; Phase 4 adds purchase and deeds.
class_name PlotDef
extends Resource

@export var id: StringName
@export var zone_id: StringName
@export var min_cell := Vector3i.ZERO
@export var max_cell := Vector3i.ZERO
@export var owned_from_start := false
@export var price_coins := 0


func contains(zone: StringName, cell: Vector3i) -> bool:
	return zone == zone_id and cell.x >= min_cell.x and cell.x <= max_cell.x \
		and cell.y >= min_cell.y and cell.y <= max_cell.y and cell.z >= min_cell.z and cell.z <= max_cell.z
