class_name IdleBusiness
extends RefCounted

var id: String = ""
var name: String = ""
var base_cost: float = 0.0
var cost_multiplier: float = 1.15
var base_income: float = 0.0
var duration: float = 1.0 # Duration in seconds
var is_automated: bool = false
var is_producing: bool = false

var level: int = 0
var progress: float = 0.0 # Elapsed seconds in current production cycle

var revenue_mult: float = 1.0
var speed_mult: float = 1.0

func _init(p_id: String, p_name: String, p_base_cost: float, p_cost_mult: float, p_base_income: float, p_duration_sec: float, p_is_auto: bool) -> void:
	id = p_id
	name = p_name
	base_cost = p_base_cost
	cost_multiplier = p_cost_mult
	base_income = p_base_income
	duration = max(0.1, p_duration_sec)
	is_automated = p_is_auto
	level = 1 if p_id == "corn" else 0 # First business unlocked by default

func is_owned() -> bool:
	return level > 0

func cost() -> float:
	return base_cost * pow(cost_multiplier, level)

func income() -> float:
	if level == 0:
		return 0.0
	return base_income * float(level) * revenue_mult

func get_effective_duration() -> float:
	return max(0.05, duration / max(0.1, speed_mult))

func get_gps() -> float:
	if not is_owned() or not is_automated:
		return 0.0
	return income() / get_effective_duration()

func trigger_production() -> bool:
	if not is_owned() or is_producing:
		return false
	is_producing = true
	progress = 0.0
	return true

func update_progress(delta: float) -> float:
	if not is_owned():
		return 0.0

	# Auto-start if automated and idle
	if is_automated and not is_producing:
		is_producing = true
		progress = 0.0

	if not is_producing:
		return 0.0

	progress += delta
	var eff_duration: float = get_effective_duration()

	if progress >= eff_duration:
		var harvests: int = int(floor(progress / eff_duration))
		progress = fmod(progress, eff_duration)

		if not is_automated:
			is_producing = false
			progress = 0.0

		return income() * float(harvests)

	return 0.0

func buy_level() -> void:
	level += 1

func get_progress_ratio() -> float:
	if not is_producing:
		return 0.0
	return clamp(progress / get_effective_duration(), 0.0, 1.0)
