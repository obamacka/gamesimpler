## Outfit piece (spec 3.4). Placeholder mesh: a colored box per slot; dye tints it.
class_name OutfitDef
extends Resource

const SLOTS: Array[StringName] = [&"HEAD", &"TOP", &"BOTTOM", &"FEET", &"ACCESSORY"]

@export var id: StringName
@export var item_id: StringName
@export var slot: StringName = &"TOP"
@export var color := Color.WHITE
@export var dyeable := true
@export var default_dye_id: StringName = &""
@export var hide_body_regions: Array[StringName] = []
