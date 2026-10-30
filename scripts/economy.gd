class_name Wallet
extends Node
## Единственный владелец баланса. Изменение происходит до отправки сигнала,
## поэтому повторный/reentrant try_spend видит уже списанную сумму.
signal points_changed(new_value: int, delta: int)
var _points := 0
var points: int:
	get:
		return _points
	set(_value):
		push_error("Изменяйте баланс только через Wallet")


func can_afford(cost: int) -> bool:
	return cost >= 0 and _points >= cost


func try_spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	_points -= cost
	points_changed.emit(_points, -cost)
	return true


func add_points(amount: int) -> void:
	if amount <= 0:
		return
	_points += amount
	points_changed.emit(_points, amount)
