class_name IdleManager
extends RefCounted

var id: String = ""
var name: String = ""
var description: String = ""
var cost: float = 0.0
var target_business_id: String = ""
var is_hired: bool = false

func _init(p_id: String, p_name: String, p_desc: String, p_cost: float, p_target: String) -> void:
	id = p_id
	name = p_name
	description = p_desc
	cost = p_cost
	target_business_id = p_target
	is_hired = false
