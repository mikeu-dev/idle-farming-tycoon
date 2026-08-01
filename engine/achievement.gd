class_name IdleAchievement
extends RefCounted

var id: String = ""
var name: String = ""
var description: String = ""
var condition_type: String = "" # "balance" or "level"
var target_business_id: String = ""
var target_value: float = 0.0
var bonus_multiplier: float = 0.0
var is_unlocked: bool = false

func _init(p_id: String, p_name: String, p_desc: String, p_type: String, p_target: String, p_val: float, p_bonus: float) -> void:
	id = p_id
	name = p_name
	description = p_desc
	condition_type = p_type
	target_business_id = p_target
	target_value = p_val
	bonus_multiplier = p_bonus
	is_unlocked = false
