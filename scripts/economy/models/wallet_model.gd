## Integer coin wallet, never negative (spec 1.8). Phase 2 needs coins from chests;
## Phase 4 adds the TransactionCoordinator on top.
class_name WalletModel
extends RefCounted

var coins := 0


func credit(amount: int) -> bool:
	if amount < 0:
		return false
	coins += amount
	return true


func can_afford(amount: int) -> bool:
	return amount >= 0 and coins >= amount


func debit(amount: int) -> bool:
	if not can_afford(amount):
		return false
	coins -= amount
	return true


func to_dict() -> Dictionary:
	return {"coins": coins}


func from_dict(d: Dictionary) -> void:
	coins = maxi(0, int(d.get("coins", 0)))
