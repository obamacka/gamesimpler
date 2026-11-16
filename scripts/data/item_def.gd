## Item definition (spec 3.1). Authored in res://resources/data/items.json, built by Database.
class_name ItemDef
extends Resource

@export var id: StringName
@export var name_key := ""
@export var desc_key := ""
@export var category: StringName = &"RESOURCE"
@export var max_stack := 99
@export var base_value := 0
@export var sellable := true
@export var giftable := true
@export var tags: Array[StringName] = []
@export var has_instance_data := false
@export var tool: ToolData
@export var food: FoodData
@export var block_material: StringName = &""   # BLOCK items: the VoxelMaterialDef they place
@export var seed_crop: StringName = &""        # SEED items: the CropDef they plant
