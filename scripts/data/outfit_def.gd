## Outfit piece (spec 3.4, 11.6). `parts` are Quaternius outfit files per body type; pieces
## without parts show a coloured placeholder box on the slot bone. Dye tints either.
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
## {"MALE": [outfit file names], "FEMALE": [...]} under res://assets/third_party/quaternius/outfits/
@export var parts: Dictionary = {}
## Optional alternate base-colour texture file in the same folder.
@export var texture := ""


func parts_for(body: StringName) -> Array:
	return parts.get(body, [])
