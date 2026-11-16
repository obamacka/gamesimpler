## Pet accessory (spec 3.4). `species` lists the species that have a mesh for it.
class_name PetAccessoryDef
extends Resource

const SLOTS: Array[StringName] = [&"HEAD", &"NECK", &"BODY"]

@export var item_id: StringName
@export var slot: StringName = &"HEAD"
@export var species: Array[StringName] = []
@export var dyeable := true
@export var default_dye_id: StringName = &""
@export var color := Color.WHITE
