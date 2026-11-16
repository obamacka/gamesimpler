## Authored protection volume (spec 9.3 P1). Cells min..max inclusive.
class_name ProtectionVolume
extends Node3D

@export var min_cell := Vector3i.ZERO
@export var max_cell := Vector3i.ZERO
@export var reason: StringName = &"TOWN"
@export var allows_place := false
