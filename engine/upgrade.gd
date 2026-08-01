class_name IdleUpgrade
extends RefCounted

var id: String = ""
var name: String = ""
var description: String = ""
var cost: float = 0.0
var target_business_id: String = ""
var revenue_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var is_purchased: bool = false

func _init(p_id: String, p_name: String, p_desc: String, p_cost: float, p_target: String, p_rev_mult: float, p_speed_mult: float) -> void:
	id = p_id
	name = p_name
	description = p_desc
	cost = p_cost
	target_business_id = p_target
	revenue_multiplier = p_rev_mult
	speed_multiplier = p_speed_mult
	is_purchased = false
