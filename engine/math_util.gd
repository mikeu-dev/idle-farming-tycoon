class_name IdleMathUtil
extends RefCounted

## Calculates the maximum affordable levels and total cost for a business using O(1) geometric series math.
static func calculate_max_affordable(base_cost: float, cost_multiplier: float, current_level: int, balance: float) -> Dictionary:
	if balance < 0 or base_cost <= 0 or cost_multiplier <= 1.0:
		return {"count": 0, "cost": 0.0}

	var cur_cost: float = base_cost * pow(cost_multiplier, current_level)
	if balance < cur_cost:
		return {"count": 0, "cost": 0.0}

	# Closed-form geometric series calculation:
	# n = floor( log(1 + balance * (r - 1) / (base_cost * r^level)) / log(r) )
	var r: float = cost_multiplier
	var term: float = 1.0 + (balance * (r - 1.0)) / cur_cost
	if term <= 0:
		return {"count": 0, "cost": 0.0}

	var count: int = int(floor(log(term) / log(r)))
	if count <= 0:
		count = 1

	# Exact total cost formula: Total = cur_cost * (r^n - 1) / (r - 1)
	var total_cost: float = cur_cost * (pow(r, count) - 1.0) / (r - 1.0)
	return {"count": count, "cost": total_cost}
