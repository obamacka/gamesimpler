## Non-violent discovery tuning (spec 6.4).
class_name DiscoveryConfig
extends Resource

@export var geode_item_id: StringName = &"item_geode"
@export var geode_pity := 40            # hard voxels dug without a geode
@export var chest_pity := 150           # voxels dug without revealing a chest
