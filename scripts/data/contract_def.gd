## Contract (spec 3.4): BUILD_BLUEPRINT, DELIVER_ITEMS or CRAFT_ITEMS.
class_name ContractDef
extends Resource

@export var id: StringName
@export var job_id: StringName
@export var kind: StringName = &"DELIVER_ITEMS"
@export var blueprint: StringName = &""
@export var items: Array = []      # [{"item", "qty"}] to deliver or craft
@export var provided: Array = []   # [{"item", "qty"}] mailed the next day
@export var pay := 0
@export var xp := 0
@export var days := 3
@export var min_rank := 0
