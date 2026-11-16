## Loot table (spec 3.4). entries: [{item: id or "coins", min, max, weight}].
class_name LootTableDef
extends Resource

@export var id: StringName
@export var rolls := 1
@export var entries: Array = []
@export var guaranteed: Array = []   # [{item, qty}]
