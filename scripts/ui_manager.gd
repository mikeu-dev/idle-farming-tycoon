extends Control

class_name UIManager

var engine_ref: IdleEngine

var active_tab: int = 0
var buy_max_mode: bool = false
var notification_msg: String = ""
var notification_expiry: float = 0.0

var floating_texts: Array = []

const BUTTON_TEXTURE_PATHS := {
	"green": "res://assets/kenney_ui-pack/PNG/Green/Default/button_rectangle_depth_gradient.png",
	"yellow": "res://assets/kenney_ui-pack/PNG/Yellow/Default/button_rectangle_depth_gradient.png",
	"grey": "res://assets/kenney_ui-pack/PNG/Grey/Default/button_rectangle_depth_gradient.png",
	"blue": "res://assets/kenney_ui-pack/PNG/Blue/Default/button_rectangle_depth_gradient.png",
}

var _button_styles: Dictionary = {}

const SFX_CLICK_PATH := "res://assets/kenney_ui-pack/Sounds/click-a.ogg"
const SFX_SWITCH_PATH := "res://assets/kenney_ui-pack/Sounds/switch-a.ogg"

var _sfx_click: AudioStreamPlayer
var _sfx_switch: AudioStreamPlayer

func _ready() -> void:
	for style_key in BUTTON_TEXTURE_PATHS:
		var path: String = BUTTON_TEXTURE_PATHS[style_key]
		if not ResourceLoader.exists(path):
			continue
		var sbt := StyleBoxTexture.new()
		sbt.texture = load(path)
		sbt.texture_margin_left = 14
		sbt.texture_margin_right = 14
		sbt.texture_margin_top = 10
		sbt.texture_margin_bottom = 16
		_button_styles[style_key] = sbt

	_sfx_click = AudioStreamPlayer.new()
	_sfx_switch = AudioStreamPlayer.new()
	add_child(_sfx_click)
	add_child(_sfx_switch)
	if ResourceLoader.exists(SFX_CLICK_PATH):
		_sfx_click.stream = load(SFX_CLICK_PATH)
	if ResourceLoader.exists(SFX_SWITCH_PATH):
		_sfx_switch.stream = load(SFX_SWITCH_PATH)

func _play_click() -> void:
	if _sfx_click.stream != null:
		_sfx_click.play()

func _play_switch() -> void:
	if _sfx_switch.stream != null:
		_sfx_switch.play()

func setup(eng: IdleEngine) -> void:
	engine_ref = eng
	if engine_ref != null:
		engine_ref.harvest_produced.connect(_on_harvest_produced)
		engine_ref.notification_emitted.connect(_on_notification_emitted)

func set_notification(msg: String) -> void:
	notification_msg = msg
	notification_expiry = Time.get_unix_time_from_system() + 3.0

func _on_harvest_produced(biz_id: String, income: float) -> void:
	var pos = Vector2(180, 200)
	if biz_id == "wheat": pos = Vector2(180, 300)
	elif biz_id == "livestock": pos = Vector2(180, 400)
	elif biz_id == "greenhouse": pos = Vector2(180, 500)
	elif biz_id == "processing": pos = Vector2(180, 600)

	floating_texts.append({
		"pos": pos,
		"text": "+%.1f Poin! 🌾" % income,
		"alpha": 1.0,
		"time": 1.2
	})

func _on_notification_emitted(msg: String) -> void:
	set_notification(msg)

func _process(delta: float) -> void:
	# Update floating texts
	var active_list = []
	for ft in floating_texts:
		ft["time"] -= delta
		if ft["time"] > 0:
			ft["pos"].y -= 20.0 * delta
			ft["alpha"] = ft["time"] / 1.2
			active_list.append(ft)
	floating_texts = active_list

	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = event.position
		_handle_ui_click(pos)

func _handle_ui_click(pos: Vector2) -> void:
	if engine_ref == null:
		return

	# Header Buttons (Super Boost & Time Warp)
	if pos.y >= 45 and pos.y <= 77:
		if pos.x >= 700 and pos.x <= 840:
			_play_click()
			if engine_ref.trigger_super_boost():
				set_notification("SUPER BOOST DIAKTIFKAN (2X SPEED 30S)")
			else:
				set_notification("POIN TIDAK CUKUP UNTUK SUPER BOOST (50P)")
		elif pos.x >= 850 and pos.x <= 990:
			_play_click()
			if engine_ref.trigger_time_warp():
				set_notification("TIME WARP DILAKUKAN (+1 JAM INCOME)")
			else:
				set_notification("POIN TIDAK CUKUP UNTUK TIME WARP (150P)")
		return

	# Tab Bar Clicks (x: 535-980, y: 95-128)
	if pos.y >= 95 and pos.y <= 128 and pos.x >= 535:
		var prev_tab := active_tab
		if pos.x <= 620: active_tab = 0
		elif pos.x <= 710: active_tab = 1
		elif pos.x <= 800: active_tab = 2
		elif pos.x <= 890: active_tab = 3
		elif pos.x <= 980: active_tab = 4
		if active_tab != prev_tab:
			_play_switch()
		return

	# Right Panel Action Clicks
	if pos.x >= 535 and pos.x <= 1005:
		if active_tab == 0: # Lahan Tab
			# Toggle Buy Mode Button
			if pos.y >= 133 and pos.y <= 159 and pos.x >= 545 and pos.x <= 675:
				_play_click()
				buy_max_mode = not buy_max_mode
				set_notification("MODE BELI: " + ("BUY MAX" if buy_max_mode else "BUY 1X"))
				return

			var bizs = engine_ref.businesses
			for i in range(bizs.size()):
				var card_y = 165 + i * 105
				if pos.y >= card_y and pos.y <= card_y + 95:
					if pos.x >= 830 and pos.x <= 980:
						_play_click()
						var b_id = bizs[i].id
						if buy_max_mode:
							var res = engine_ref.buy_upgrade_max_by_id(b_id)
							if res["count"] > 0:
								set_notification("MEMBELI +%d LEVEL %s (%.1fP)" % [res["count"], b_id, res["cost"]])
						else:
							if engine_ref.buy_upgrade_by_id(b_id):
								set_notification("BERHASIL UPGRADE LEVEL " + b_id)

		elif active_tab == 1: # Upgrades Tab
			var upgs = engine_ref.upgrades
			for i in range(upgs.size()):
				var card_y = 140 + i * 95
				if pos.y >= card_y and pos.y <= card_y + 80:
					if pos.x >= 830 and pos.x <= 980:
						_play_click()
						if engine_ref.buy_upgrade_card_by_id(upgs[i].id):
							set_notification("BERHASIL BELI UPGRADE: " + upgs[i].name)

		elif active_tab == 2: # Managers Tab
			var mgrs = engine_ref.managers
			for i in range(mgrs.size()):
				var card_y = 140 + i * 95
				if pos.y >= card_y and pos.y <= card_y + 80:
					if pos.x >= 830 and pos.x <= 980:
						_play_click()
						if engine_ref.buy_manager_by_id(mgrs[i].id):
							set_notification("BERHASIL REKRUT MANDOR: " + mgrs[i].name)

		elif active_tab == 4: # Festival Tab
			if pos.y >= 360 and pos.y <= 420 and pos.x >= 570 and pos.x <= 970:
				_play_click()
				if engine_ref.claim_prestige():
					set_notification("FESTIVAL PANEN RAYA BERHASIL! ANGEL INVESTOR DIKLAIM!")
				else:
					set_notification("PROGRES BELUM CUKUP UNTUK FESTIVAL!")

func _draw() -> void:
	if engine_ref == null:
		return

	# 1. Header Banner Background
	draw_rect(Rect2(0, 0, 1024, 85), Color(0.08, 0.11, 0.07, 1.0), true)
	draw_rect(Rect2(0, 83, 1024, 2), Color(0.55, 0.76, 0.29, 1.0), true)

	draw_string(ThemeDB.fallback_font, Vector2(55, 32), "IDLE FARMING TYCOON (GODOT 4)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.76, 0.03, 1.0))

	# Wallet Balance & GPS
	var bal_str = "SALDO: %.2f POIN" % engine_ref.wallet.balance()
	draw_string(ThemeDB.fallback_font, Vector2(55, 54), bal_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	var total_gps: float = 0.0
	for b in engine_ref.businesses:
		total_gps += b.get_gps()

	var angel_bonus: float = float(engine_ref.angels) * 5.0
	var status_str = "HASIL/DETIK: %.2f P/S | ANGEL: %d (+%.0f%%)" % [total_gps, engine_ref.angels, angel_bonus]
	draw_string(ThemeDB.fallback_font, Vector2(55, 74), status_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.76, 0.29, 1.0))

	# Super Boost & Time Warp Buttons
	var boost_txt = "BOOST 2X"
	if engine_ref.boost_duration > 0:
		boost_txt = "BOOST %.1fS" % engine_ref.boost_duration
	_draw_button(Rect2(700, 45, 140, 32), boost_txt, "yellow", Color.BLACK)
	_draw_button(Rect2(850, 45, 140, 32), "WARP 1H", "green", Color.WHITE)

	# 2. Right Management Window Frame
	var panel_rect = Rect2(530, 95, 475, 635)
	draw_rect(panel_rect, Color(0.16, 0.20, 0.14, 1.0), true)
	draw_rect(panel_rect, Color(0.55, 0.76, 0.29, 1.0), false, 2.0)

	# Tab Menu Bar
	var tabs = ["LAHAN", "UPGRADE", "MANDOR", "PRESTASI", "FESTIVAL"]
	for i in range(tabs.size()):
		var tab_x = 535 + i * 88
		var tab_style = "blue" if i != active_tab else "green"
		_draw_button(Rect2(tab_x, 98, 82, 30), tabs[i], tab_style, Color.WHITE)

	# Active Tab Content
	match active_tab:
		0: _draw_lahan_tab()
		1: _draw_upgrade_tab()
		2: _draw_mandor_tab()
		3: _draw_prestasi_tab()
		4: _draw_festival_tab()

	# Bottom Notification Bar
	if Time.get_unix_time_from_system() < notification_expiry and notification_msg != "":
		draw_rect(Rect2(0, 735, 1024, 33), Color(1.0, 0.76, 0.03, 1.0), true)
		draw_string(ThemeDB.fallback_font, Vector2(20, 757), "📢 " + notification_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.08, 0.11, 0.07, 1.0))

	# Floating Text FX
	for ft in floating_texts:
		var c = Color(0.30, 0.69, 0.31, ft["alpha"])
		draw_string(ThemeDB.fallback_font, ft["pos"], ft["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)

func _draw_lahan_tab() -> void:
	# Buy Mode Toggle Button
	var buy_str = "BUY 1X" if not buy_max_mode else "BUY MAX"
	var buy_style = "grey" if not buy_max_mode else "yellow"
	_draw_button(Rect2(545, 133, 130, 26), buy_str, buy_style, Color.BLACK if buy_max_mode else Color.WHITE)

	var bizs = engine_ref.businesses
	var bal = engine_ref.wallet.balance()

	for i in range(bizs.size()):
		var b = bizs[i]
		var card_y = 165 + i * 105
		draw_rect(Rect2(545, card_y, 445, 95), Color(0.08, 0.11, 0.07, 1.0), true)

		var name_str = "%s (LVL %d)" % [b.name, b.level]
		draw_string(ThemeDB.fallback_font, Vector2(555, card_y + 24), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

		var info_str = "PANEN: %.1f P | GPS: %.1f P/S" % [b.income(), b.get_gps()]
		draw_string(ThemeDB.fallback_font, Vector2(555, card_y + 46), info_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.76, 0.29, 1.0))

		# Upgrade Button
		var buy_txt = ""
		var cost = 0.0
		if buy_max_mode:
			var res = IdleMathUtil.calculate_max_affordable(b.base_cost, b.cost_multiplier, b.level, bal)
			var cnt = res["count"] if res["count"] > 0 else 1
			cost = res["cost"] if res["count"] > 0 else b.cost()
			buy_txt = "+%d LVL (%.1fP)" % [cnt, cost]
		else:
			cost = b.cost()
			buy_txt = "+1 LVL (%.1fP)" % cost

		var btn_style = "green" if bal >= cost else "grey"
		_draw_button(Rect2(830, card_y + 22, 150, 50), buy_txt, btn_style, Color.WHITE)

func _draw_upgrade_tab() -> void:
	var upgs = engine_ref.upgrades
	var bal = engine_ref.wallet.balance()
	for i in range(upgs.size()):
		var u = upgs[i]
		var card_y = 140 + i * 95
		draw_rect(Rect2(545, card_y, 445, 82), Color(0.08, 0.11, 0.07, 1.0), true)

		draw_string(ThemeDB.fallback_font, Vector2(555, card_y + 24), "⚡ " + u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.76, 0.03, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(555, card_y + 48), u.description, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8, 1.0))

		var txt = "TERBELI" if u.is_purchased else ("BELI %.1fP" % u.cost)
		var style = "blue" if u.is_purchased else ("yellow" if bal >= u.cost else "grey")
		_draw_button(Rect2(830, card_y + 18, 150, 46), txt, style, Color.BLACK if not u.is_purchased else Color.WHITE)

func _draw_mandor_tab() -> void:
	var mgrs = engine_ref.managers
	var bal = engine_ref.wallet.balance()
	for i in range(mgrs.size()):
		var m = mgrs[i]
		var card_y = 140 + i * 95
		draw_rect(Rect2(545, card_y, 445, 82), Color(0.08, 0.11, 0.07, 1.0), true)

		draw_string(ThemeDB.fallback_font, Vector2(555, card_y + 24), "👨‍🌾 " + m.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.76, 0.29, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(555, card_y + 48), m.description, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8, 1.0))

		var txt = "DIREKRUT" if m.is_hired else ("REKRUT %.1fP" % m.cost)
		var style = "blue" if m.is_hired else ("yellow" if bal >= m.cost else "grey")
		_draw_button(Rect2(830, card_y + 18, 150, 46), txt, style, Color.BLACK if not m.is_hired else Color.WHITE)

func _draw_prestasi_tab() -> void:
	var achs = engine_ref.achievements
	for i in range(achs.size()):
		var a = achs[i]
		var card_y = 140 + i * 95
		draw_rect(Rect2(545, card_y, 445, 82), Color(0.08, 0.11, 0.07, 1.0), true)

		draw_string(ThemeDB.fallback_font, Vector2(555, card_y + 24), "🏆 " + a.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.76, 0.03, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(555, card_y + 48), a.description, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8, 1.0))

		var txt = "TERCAPAI" if a.is_unlocked else "BELUM"
		var style = "green" if a.is_unlocked else "grey"
		_draw_button(Rect2(830, card_y + 18, 150, 46), txt, style, Color.WHITE)

func _draw_festival_tab() -> void:
	draw_rect(Rect2(545, 140, 445, 450), Color(0.08, 0.11, 0.07, 1.0), true)
	draw_string(ThemeDB.fallback_font, Vector2(620, 175), "FESTIVAL PANEN RAYA", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.76, 0.03, 1.0))

	draw_string(ThemeDB.fallback_font, Vector2(560, 210), "Gelar Festival Panen Raya untuk mereset lahan", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(560, 230), "tetapi dapatkan Angel Investor permanen!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	var owned = engine_ref.angels
	var claimable = engine_ref.calculate_angels_to_claim()

	draw_string(ThemeDB.fallback_font, Vector2(560, 270), "ANGEL DIMILIKI: %d (+%.0f%%)" % [owned, float(owned)*5.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.76, 0.29, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(560, 295), "KLAIM ANGEL BARU: +%d" % claimable, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.76, 0.03, 1.0))

	var txt = "KLAIM +%d ANGEL" % claimable if claimable > 0 else "PROGRES BELUM CUKUP"
	var style = "yellow" if claimable > 0 else "grey"
	_draw_button(Rect2(570, 360, 400, 60), txt, style, Color.BLACK if claimable > 0 else Color.WHITE)

func _draw_button(rect: Rect2, label: String, style: String, txt_color: Color) -> void:
	if _button_styles.has(style):
		draw_style_box(_button_styles[style], rect)
	else:
		draw_rect(rect, Color(0.3, 0.3, 0.3, 1.0), true)
		draw_rect(rect, Color.WHITE, false, 1.0)
	var text_pos = Vector2(rect.position.x + (rect.size.x / 2.0) - (label.length() * 3.5), rect.position.y + (rect.size.y / 2.0) + 4)
	draw_string(ThemeDB.fallback_font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, txt_color)
