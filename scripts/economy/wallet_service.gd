class_name WalletService
extends Node

var model := WalletModel.new()


func credit(amount: int) -> void:
	var old := model.coins
	if model.credit(amount) and amount > 0:
		EventBus.coins_changed.emit(old, model.coins)


func debit(amount: int) -> bool:
	var old := model.coins
	if not model.debit(amount):
		return false
	EventBus.coins_changed.emit(old, model.coins)
	return true
