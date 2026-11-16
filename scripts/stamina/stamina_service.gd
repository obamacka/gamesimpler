## Stamina service (spec 6.1). Sets `exhaustion_pending` on the depletion edge; the player FSM
## enters Sleep once its current step resolves, and SleepDirector clears the flag on waking.
class_name StaminaService
extends Node

var model := StaminaModel.new()
var exhaustion_pending := false


func _ready() -> void:
	model.configure(Database.stamina)


func can_act() -> bool:
	return model.can_act()


func spend(amount: int, reason: StringName) -> int:
	var old := model.current
	var r := model.spend(amount)
	if r["spent"] > 0:
		EventBus.stamina_changed.emit(old, model.current, reason)
	for pct in r["low_crossed"]:
		EventBus.stamina_low.emit(pct)
	if r["depleted_now"]:
		exhaustion_pending = true
		EventBus.stamina_depleted.emit()
	return r["spent"]


func restore(amount: int, reason: StringName) -> void:
	var old := model.current
	if model.restore(amount) > 0:
		EventBus.stamina_changed.emit(old, model.current, reason)


func refill() -> void:
	var old := model.current
	model.refill()
	exhaustion_pending = false
	if model.current != old:
		EventBus.stamina_changed.emit(old, model.current, &"wake")
