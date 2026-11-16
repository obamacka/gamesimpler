## Collection entry (spec 3.7), embedded in ItemDef.collection. Key = item id; instance data
## (dye) never makes a separate entry.
class_name CollectionEntryDef
extends Resource

@export var category: StringName = &"MINERAL"   # MINERAL, FABRIC, PRODUCE
@export var set_id: StringName = &""
@export var case_id: StringName = &""
@export var hint_key := ""
@export var sort_order := 0
