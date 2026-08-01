class_name IdleWallet
extends RefCounted

var _balance: float = 0.0

func _init(initial_balance: float = 0.0) -> void:
	_balance = initial_balance

func balance() -> float:
	return _balance

func add(amount: float) -> void:
	if amount > 0:
		_balance += amount

func spend(amount: float) -> bool:
	if amount > 0 and _balance >= amount:
		_balance -= amount
		return true
	return false

func set_balance(val: float) -> void:
	_balance = max(0.0, val)
