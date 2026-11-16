## Treasure chest table (spec 3.4, 6.4). entries: [{kind, id_pool, weight, coins_min, coins_max}].
## kind: BLUEPRINT, DYE, STICKER (unlocks, never duplicated), COINS, ITEM ({item, qty}).
class_name TreasureTableDef
extends Resource

@export var id: StringName
@export var entries: Array = []
@export var fallback_coins_min := 20
@export var fallback_coins_max := 40
