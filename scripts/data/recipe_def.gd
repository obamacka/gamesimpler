## Recipe (spec 3.2). inputs/outputs: [{"item": StringName, "qty": int}].
class_name RecipeDef
extends Resource

@export var id: StringName
@export var station: StringName = &"HAND"   # HAND, WORKBENCH, TAILOR_BENCH
@export var inputs: Array = []
@export var outputs: Array = []
@export var coin_cost := 0
@export var craft_time_sec := 0.0
@export var required_job: StringName = &""
@export var required_rank := 0
@export var unlock: StringName = &"DEFAULT"   # DEFAULT, JOB_RANK, MAIL, PURCHASE, BLUEPRINT
@export var xp_reward := 0
