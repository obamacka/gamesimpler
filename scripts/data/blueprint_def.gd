## Blueprint (spec 3.4). Piece cells are relative to the site origin: (site_min.x, ground
## top + 1, site_min.z). Every piece must be FASTENED to complete the contract.
class_name BlueprintDef
extends Resource

@export var id: StringName
@export var zone_id: StringName
@export var site_min := Vector3i.ZERO
@export var site_max := Vector3i.ZERO
@export var pieces: Array = []   # [{"piece_id", "cell": Vector3i, "rot": int}]
