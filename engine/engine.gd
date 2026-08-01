class_name IdleEngine
extends RefCounted

var wallet: IdleWallet
var businesses: Array[IdleBusiness] = []
var upgrades: Array[IdleUpgrade] = []
var managers: Array[IdleManager] = []
var achievements: Array[IdleAchievement] = []

var lifetime_earnings: float = 4.0
var angels: int = 0
var boost_duration: float = 0.0

signal harvest_produced(business_id: String, income: float)
signal notification_emitted(message: String)

func _init(config_path: String = "res://configs/farming_config.json") -> void:
	wallet = IdleWallet.new(4.0)
	load_config(config_path)

func load_config(config_path: String) -> void:
	businesses.clear()
	upgrades.clear()
	managers.clear()
	achievements.clear()

	if not FileAccess.file_exists(config_path):
		return

	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()

	var cfg = JSON.parse_string(json_text)
	if typeof(cfg) != TYPE_DICTIONARY:
		return

	# Load Businesses
	if cfg.has("businesses"):
		for bc in cfg["businesses"]:
			var b = IdleBusiness.new(
				bc["id"],
				bc["name"],
				bc["base_cost"],
				bc["cost_multiplier"],
				bc["base_income"],
				float(bc["duration_ms"]) / 1000.0,
				bc["is_automated"]
			)
			businesses.append(b)

	# Load Upgrades
	if cfg.has("upgrades"):
		for uc in cfg["upgrades"]:
			var u = IdleUpgrade.new(
				uc["id"],
				uc["name"],
				uc["description"],
				uc["cost"],
				uc["target_business_id"],
				uc["revenue_multiplier"],
				uc["speed_multiplier"]
			)
			upgrades.append(u)

	# Load Managers
	if cfg.has("managers"):
		for mc in cfg["managers"]:
			var m = IdleManager.new(
				mc["id"],
				mc["name"],
				mc["description"],
				mc["cost"],
				mc["target_business_id"]
			)
			managers.append(m)

	# Load Achievements
	if cfg.has("achievements"):
		for ac in cfg["achievements"]:
			var a = IdleAchievement.new(
				ac["id"],
				ac["name"],
				ac["description"],
				ac["condition_type"],
				ac["target_business_id"],
				ac["target_value"],
				ac["bonus_multiplier"]
			)
			achievements.append(a)

func update(delta: float) -> void:
	if boost_duration > 0:
		boost_duration = max(0.0, boost_duration - delta)

	var speed_boost: float = 2.0 if boost_duration > 0 else 1.0

	# Calculate Angel investor global multiplier (+5% per angel)
	var angel_mult: float = 1.0 + (float(angels) * 0.05)

	# Update business progress
	for b in businesses:
		var raw_harvest: float = b.update_progress(delta * speed_boost)
		if raw_harvest > 0.0:
			var total_harvest: float = raw_harvest * angel_mult
			wallet.add(total_harvest)
			lifetime_earnings += total_harvest
			harvest_produced.emit(b.id, total_harvest)

	check_achievements()

func check_achievements() -> void:
	for ach in achievements:
		if ach.is_unlocked:
			continue

		var unlocked: bool = false
		if ach.condition_type == "balance":
			if wallet.balance() >= ach.target_value:
				unlocked = true
		elif ach.condition_type == "level":
			for b in businesses:
				if b.id == ach.target_business_id and b.level >= int(ach.target_value):
					unlocked = true
					break

		if unlocked:
			ach.is_unlocked = true
			notification_emitted.emit("🏆 PRESTASI TERCAPAI: " + ach.name)

func trigger_production_by_id(biz_id: String) -> bool:
	for b in businesses:
		if b.id == biz_id:
			return b.trigger_production()
	return false

func buy_upgrade_by_id(biz_id: String) -> bool:
	for b in businesses:
		if b.id == biz_id:
			var c: float = b.cost()
			if wallet.spend(c):
				b.buy_level()
				return true
	return false

func buy_upgrade_max_by_id(biz_id: String) -> Dictionary:
	for b in businesses:
		if b.id == biz_id:
			var res = IdleMathUtil.calculate_max_affordable(b.base_cost, b.cost_multiplier, b.level, wallet.balance())
			if res["count"] > 0 and wallet.spend(res["cost"]):
				b.level += res["count"]
				return res
	return {"count": 0, "cost": 0.0}

func buy_upgrade_card_by_id(upg_id: String) -> bool:
	for u in upgrades:
		if u.id == upg_id and not u.is_purchased:
			if wallet.spend(u.cost):
				u.is_purchased = true
				apply_upgrade(u)
				return true
	return false

func apply_upgrade(u: IdleUpgrade) -> void:
	for b in businesses:
		if b.id == u.target_business_id:
			b.revenue_mult *= u.revenue_multiplier
			b.speed_mult *= u.speed_multiplier

func buy_manager_by_id(mgr_id: String) -> bool:
	for m in managers:
		if m.id == mgr_id and not m.is_hired:
			if wallet.spend(m.cost):
				m.is_hired = true
				for b in businesses:
					if b.id == m.target_business_id:
						b.is_automated = true
				return true
	return false

func trigger_super_boost() -> bool:
	if wallet.spend(50.0):
		boost_duration = 30.0
		return true
	return false

func trigger_time_warp() -> bool:
	if wallet.spend(150.0):
		var total_gps: float = 0.0
		for b in businesses:
			total_gps += b.get_gps()
		var warp_earnings: float = total_gps * 3600.0
		wallet.add(warp_earnings)
		lifetime_earnings += warp_earnings
		return true
	return false

func calculate_angels_to_claim() -> int:
	if lifetime_earnings < 1000.0:
		return 0
	var total_angels: int = int(floor(sqrt(lifetime_earnings / 1000.0)))
	return max(0, total_angels - angels)

func claim_prestige() -> bool:
	var new_angels: int = calculate_angels_to_claim()
	if new_angels <= 0:
		return false

	angels += new_angels

	# Reset businesses
	for b in businesses:
		b.level = 1 if b.id == "corn" else 0
		b.progress = 0.0
		b.is_producing = false
		b.revenue_mult = 1.0
		b.speed_mult = 1.0
		if b.id != "wheat" and b.id != "livestock":
			b.is_automated = false

	# Reset upgrades & managers
	for u in upgrades:
		u.is_purchased = false
	for m in managers:
		m.is_hired = false

	wallet.set_balance(4.0)
	return true

func export_state() -> Dictionary:
	var biz_states = []
	for b in businesses:
		biz_states.append({
			"id": b.id,
			"level": b.level,
			"is_automated": b.is_automated,
			"progress": b.progress,
			"revenue_mult": b.revenue_mult,
			"speed_mult": b.speed_mult
		})

	var upg_states = []
	for u in upgrades:
		upg_states.append({"id": u.id, "purchased": u.is_purchased})

	var mgr_states = []
	for m in managers:
		mgr_states.append({"id": m.id, "hired": m.is_hired})

	var ach_states = []
	for a in achievements:
		ach_states.append({"id": a.id, "unlocked": a.is_unlocked})

	return {
		"wallet": wallet.balance(),
		"lifetime_earnings": lifetime_earnings,
		"angels": angels,
		"saved_at": Time.get_unix_time_from_system(),
		"businesses": biz_states,
		"upgrades": upg_states,
		"managers": mgr_states,
		"achievements": ach_states
	}

func import_state(state: Dictionary) -> float:
	if state.has("wallet"):
		wallet.set_balance(state["wallet"])
	if state.has("lifetime_earnings"):
		lifetime_earnings = state["lifetime_earnings"]
	if state.has("angels"):
		angels = state["angels"]

	if state.has("businesses"):
		for bs in state["businesses"]:
			for b in businesses:
				if b.id == bs["id"]:
					b.level = bs["level"]
					b.is_automated = bs["is_automated"]
					b.progress = bs["progress"]
					if bs.has("revenue_mult"):
						b.revenue_mult = bs["revenue_mult"]
					if bs.has("speed_mult"):
						b.speed_mult = bs["speed_mult"]

	if state.has("upgrades"):
		for us in state["upgrades"]:
			for u in upgrades:
				if u.id == us["id"]:
					u.is_purchased = us["purchased"]

	if state.has("managers"):
		for ms in state["managers"]:
			for m in managers:
				if m.id == ms["id"]:
					m.is_hired = ms["hired"]

	if state.has("achievements"):
		for as_item in state["achievements"]:
			for a in achievements:
				if a.id == as_item["id"]:
					a.is_unlocked = as_item["unlocked"]

	# Offline revenue calculation
	var offline_earnings: float = 0.0
	if state.has("saved_at"):
		var last_saved: float = state["saved_at"]
		var now: float = Time.get_unix_time_from_system()
		var elapsed: float = now - last_saved
		if elapsed > 10.0:
			var total_gps: float = 0.0
			for b in businesses:
				total_gps += b.get_gps()
			offline_earnings = total_gps * elapsed * 0.8 # 80% offline efficiency
			wallet.add(offline_earnings)
			lifetime_earnings += offline_earnings

	return offline_earnings
