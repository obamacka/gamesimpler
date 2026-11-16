## Mail template (spec 3.3). attachments: [{type, item_id, qty, amount, ...}].
class_name MailTemplateDef
extends Resource

@export var id: StringName
@export var sender_id: StringName = &"system"
@export var kind: StringName = &"LETTER"
@export var subject_key := ""
@export var body_key := ""
@export var pool_id: StringName = &""
@export var expires_after_days := 0
@export var attachments: Array = []
@export var has_snack := false
