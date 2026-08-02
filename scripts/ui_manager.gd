extends Control

class_name UIManager

var engine_ref: IdleEngine

var active_tab: int = 0
var buy_max_mode: bool = false
var notification_msg: String = ""
var notification_expiry: float = 0.0

var floating_texts: Array = []
var sparkles: Array = []

const BOUNCE_DURATION := 0.18
var _bounce_anim: Dictionary = {} # business_id -> remaining time

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

# kenney_tiny-farm tile indices (16px, 1px spacing, 12 cols), verified visually.
const FARM_ICON_TILES := {
	"corn": 33,
	"wheat": 69,
	"livestock": 122,
	"processing": 92, # barn wall, reused as a generic "processing building" placeholder
}
# kenney_pixel-platformer-farm-expansion greenhouse building (18px, 1px spacing, 16 cols),
# a 4x3 tile block starting at (col 0, row 4).
const GREENHOUSE_SRC := Rect2(0, 76, 75, 56)

# Field centers mirrored from farm_map.gd's grid (HUD_HEIGHT=76, GRID_MARGIN_X=16,
# COL_GAP=12, ROW_GAP=16, COL_WIDTH=338, ROW_HEIGHT=190) — used to anchor floating
# harvest text/sparkles at the right spot on screen.
const ZONE_CENTERS := {
	"corn": Vector2(185, 187),
	"wheat": Vector2(535, 187),
	"livestock": Vector2(185, 393),
	"greenhouse": Vector2(535, 393),
	"processing": Vector2(360, 599),
}

# Portrait layout (see project.godot: 720x1280)
const HUD_HEIGHT := 76
const SHEET_Y := 720
const TAB_BAR_HEIGHT := 72
const CONTENT_Y := SHEET_Y + TAB_BAR_HEIGHT + 8
const CARD_X := 12
const CARD_W := 696

var farm_tilemap_tex: Texture2D
var farmexp_tilemap_tex: Texture2D
var _font: Font = ThemeDB.fallback_font

func _ready() -> void:
	if ResourceLoader.exists("res://assets/kenney_tiny-farm/Tilemap/tilemap_packed.png"):
		farm_tilemap_tex = load("res://assets/kenney_tiny-farm/Tilemap/tilemap_packed.png")
	if ResourceLoader.exists("res://assets/kenney_pixel-platformer-farm-expansion/Tilemap/tilemap_packed.png"):
		farmexp_tilemap_tex = load("res://assets/kenney_pixel-platformer-farm-expansion/Tilemap/tilemap_packed.png")
	if ResourceLoader.exists("res://assets/kenney_ui-pack/Font/Kenney Future.ttf"):
		_font = load("res://assets/kenney_ui-pack/Font/Kenney Future.ttf")
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
	var pos: Vector2 = ZONE_CENTERS.get(biz_id, Vector2(360, 400))

	floating_texts.append({
		"pos": pos,
		"text": "+%.1f" % income,
		"alpha": 1.0,
		"time": 1.2
	})

	for i in range(4):
		sparkles.append({
			"pos": pos,
			"vel": Vector2(randf_range(-40.0, 40.0), randf_range(-90.0, -20.0)),
			"life": 0.5,
			"max_life": 0.5,
		})

func _trigger_bounce(business_id: String) -> void:
	_bounce_anim[business_id] = BOUNCE_DURATION

## Eased "pop" scale (1.0 = resting) for the icon of a just-purchased card.
func _bounce_scale(business_id: String) -> float:
	if not _bounce_anim.has(business_id):
		return 1.0
	var t: float = _bounce_anim[business_id] / BOUNCE_DURATION
	return 1.0 + sin(t * PI) * 0.15

func _scaled_rect(rect: Rect2, factor: float) -> Rect2:
	var new_size := rect.size * factor
	var new_pos := rect.position - (new_size - rect.size) / 2.0
	return Rect2(new_pos, new_size)

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

	var active_sparkles = []
	for s in sparkles:
		s["life"] -= delta
		if s["life"] > 0:
			s["pos"] += s["vel"] * delta
			s["vel"] *= 0.9
			active_sparkles.append(s)
	sparkles = active_sparkles

	for key in _bounce_anim.keys():
		_bounce_anim[key] -= delta
		if _bounce_anim[key] <= 0.0:
			_bounce_anim.erase(key)

	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = event.position
		_handle_ui_click(pos)

func _handle_ui_click(pos: Vector2) -> void:
	if engine_ref == null:
		return

	# Header Buttons (Super Boost & Time Warp)
	if pos.y >= 12 and pos.y <= 64:
		if pos.x >= 500 and pos.x <= 604:
			_play_click()
			if engine_ref.trigger_super_boost():
				set_notification("SUPER BOOST AKTIF (2X KECEPATAN 30 DETIK)")
			else:
				set_notification("POIN TIDAK CUKUP UNTUK SUPER BOOST (50P)")
			return
		elif pos.x >= 612 and pos.x <= 708:
			_play_click()
			if engine_ref.trigger_time_warp():
				set_notification("TIME WARP: +1 JAM HASIL PANEN")
			else:
				set_notification("POIN TIDAK CUKUP UNTUK TIME WARP (150P)")
			return

	# Bottom sheet is out of bounds entirely above SHEET_Y
	if pos.y < SHEET_Y:
		return

	# Tab Bar Clicks
	if pos.y >= SHEET_Y and pos.y <= SHEET_Y + TAB_BAR_HEIGHT:
		var prev_tab := active_tab
		var tab_w: float = 720.0 / 5.0
		active_tab = clampi(int(pos.x / tab_w), 0, 4)
		if active_tab != prev_tab:
			_play_switch()
		return

	# Sheet Content Clicks
	if active_tab == 0: # Lahan Tab
		# Toggle Buy Mode Button
		if pos.y >= CONTENT_Y and pos.y <= CONTENT_Y + 28 and pos.x >= CARD_X and pos.x <= CARD_X + 140:
			_play_click()
			buy_max_mode = not buy_max_mode
			set_notification("MODE BELI: " + ("BELI MAKSIMAL" if buy_max_mode else "BELI 1 LEVEL"))
			return

		var bizs = engine_ref.businesses
		var list_y: float = CONTENT_Y + 36
		for i in range(bizs.size()):
			var card_y = list_y + i * 84
			if pos.y >= card_y and pos.y <= card_y + 78:
				if pos.x >= CARD_X + CARD_W - 148 and pos.x <= CARD_X + CARD_W - 10:
					_play_click()
					var b_id = bizs[i].id
					if buy_max_mode:
						var res = engine_ref.buy_upgrade_max_by_id(b_id)
						if res["count"] > 0:
							set_notification("MEMBELI +%d LEVEL %s (%.1fP)" % [res["count"], b_id, res["cost"]])
							_trigger_bounce(b_id)
					else:
						if engine_ref.buy_upgrade_by_id(b_id):
							set_notification("BERHASIL UPGRADE LEVEL " + b_id)
							_trigger_bounce(b_id)

	elif active_tab == 1: # Upgrades Tab
		var upgs = engine_ref.upgrades
		for i in range(upgs.size()):
			var card_y = CONTENT_Y + i * 94
			if pos.y >= card_y and pos.y <= card_y + 86:
				if pos.x >= CARD_X + CARD_W - 148 and pos.x <= CARD_X + CARD_W - 10:
					_play_click()
					if engine_ref.buy_upgrade_card_by_id(upgs[i].id):
						set_notification("BERHASIL BELI UPGRADE: " + upgs[i].name)
						_trigger_bounce(upgs[i].target_business_id)

	elif active_tab == 2: # Managers Tab
		var mgrs = engine_ref.managers
		for i in range(mgrs.size()):
			var card_y = CONTENT_Y + i * 94
			if pos.y >= card_y and pos.y <= card_y + 86:
				if pos.x >= CARD_X + CARD_W - 148 and pos.x <= CARD_X + CARD_W - 10:
					_play_click()
					if engine_ref.buy_manager_by_id(mgrs[i].id):
						set_notification("BERHASIL REKRUT MANDOR: " + mgrs[i].name)
						_trigger_bounce(mgrs[i].target_business_id)

	elif active_tab == 4: # Festival Tab
		if pos.y >= CONTENT_Y + 210 and pos.y <= CONTENT_Y + 270 and pos.x >= CARD_X + 40 and pos.x <= CARD_X + CARD_W - 40:
			_play_click()
			if engine_ref.claim_prestige():
				set_notification("FESTIVAL PANEN RAYA BERHASIL! ANGEL INVESTOR DIKLAIM!")
			else:
				set_notification("PROGRES BELUM CUKUP UNTUK FESTIVAL!")

func _draw() -> void:
	if engine_ref == null:
		return

	_draw_hud()
	_draw_sheet()

	# Floating Text FX
	for ft in floating_texts:
		var c = Color(1.0, 0.85, 0.2, ft["alpha"])
		draw_string(_font, ft["pos"], ft["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 16, c)

	# Harvest Sparkle FX
	for s in sparkles:
		var sparkle_alpha: float = s["life"] / s["max_life"]
		draw_circle(s["pos"], 3.0 * sparkle_alpha, Color(1.0, 0.9, 0.3, sparkle_alpha))

func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, 720, HUD_HEIGHT), Color(0.30, 0.20, 0.12, 1.0), true)
	draw_rect(Rect2(0, HUD_HEIGHT - 3, 720, 3), Color(0.16, 0.10, 0.06, 1.0), true)

	draw_circle(Vector2(28, 30), 10.0, Color(1.0, 0.80, 0.15, 1.0))
	draw_string(_font, Vector2(46, 36), "%.1f" % engine_ref.wallet.balance(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

	var total_gps: float = 0.0
	for b in engine_ref.businesses:
		total_gps += b.get_gps()
	var angel_bonus: float = float(engine_ref.angels) * 5.0
	var status_str = "%.1f/DETIK  •  ANGEL %d (+%.0f%%)" % [total_gps, engine_ref.angels, angel_bonus]
	draw_string(_font, Vector2(28, 58), status_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.75, 0.60, 1.0))

	var boost_txt = "BOOST"
	if engine_ref.boost_duration > 0:
		boost_txt = "%.0fS" % engine_ref.boost_duration
	_draw_button(Rect2(500, 12, 104, 52), boost_txt, "yellow", Color.BLACK)
	_draw_button(Rect2(612, 12, 96, 52), "WARP", "green", Color.WHITE)

	# Toast notification, floats just under the HUD over the farm view.
	if Time.get_unix_time_from_system() < notification_expiry and notification_msg != "":
		var toast_rect := Rect2(20, HUD_HEIGHT + 8, 680, 34)
		draw_rect(toast_rect, Color(1.0, 0.80, 0.15, 0.92), true)
		draw_string(_font, Vector2(toast_rect.position.x + 12, toast_rect.position.y + 23), notification_msg, HORIZONTAL_ALIGNMENT_LEFT, toast_rect.size.x - 24, 13, Color(0.16, 0.10, 0.06, 1.0))

func _draw_sheet() -> void:
	draw_rect(Rect2(0, SHEET_Y, 720, 1280 - SHEET_Y), Color(0.30, 0.20, 0.12, 1.0), true)
	draw_rect(Rect2(0, SHEET_Y, 720, 4), Color(1.0, 0.80, 0.15, 1.0), true)

	var tabs = ["LAHAN", "UPGRADE", "MANDOR", "PRESTASI", "FESTIVAL"]
	var tab_w: float = 720.0 / 5.0
	for i in range(tabs.size()):
		var tab_style = "blue" if i != active_tab else "green"
		_draw_button(Rect2(i * tab_w + 3, SHEET_Y + 8, tab_w - 6, TAB_BAR_HEIGHT - 14), tabs[i], tab_style, Color.WHITE)

	match active_tab:
		0: _draw_lahan_tab()
		1: _draw_upgrade_tab()
		2: _draw_mandor_tab()
		3: _draw_prestasi_tab()
		4: _draw_festival_tab()

func _draw_lahan_tab() -> void:
	var buy_str = "1X" if not buy_max_mode else "MAKS"
	var buy_style = "grey" if not buy_max_mode else "yellow"
	_draw_button(Rect2(CARD_X, CONTENT_Y, 140, 28), buy_str, buy_style, Color.BLACK if buy_max_mode else Color.WHITE)

	var bizs = engine_ref.businesses
	var bal = engine_ref.wallet.balance()
	var list_y: float = CONTENT_Y + 36

	for i in range(bizs.size()):
		var b = bizs[i]
		var card_y = list_y + i * 84
		var card_rect := Rect2(CARD_X, card_y, CARD_W, 78)
		draw_rect(card_rect, Color(0.20, 0.13, 0.08, 1.0), true)

		_draw_business_icon(b.id, _scaled_rect(Rect2(CARD_X + 8, card_y + 7, 64, 64), _bounce_scale(b.id)))

		var name_str = "%s  LV.%d" % [b.name, b.level]
		draw_string(_font, Vector2(CARD_X + 82, card_y + 28), name_str, HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 240, 14, Color.WHITE)

		var info_str = "PANEN %.1f  •  %.1f/DETIK" % [b.income(), b.get_gps()]
		draw_string(_font, Vector2(CARD_X + 82, card_y + 50), info_str, HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 240, 11, Color(0.70, 0.85, 0.60, 1.0))

		var buy_txt = ""
		var cost = 0.0
		if buy_max_mode:
			var res = IdleMathUtil.calculate_max_affordable(b.base_cost, b.cost_multiplier, b.level, bal)
			var cnt = res["count"] if res["count"] > 0 else 1
			cost = res["cost"] if res["count"] > 0 else b.cost()
			buy_txt = "+%d (%.0fP)" % [cnt, cost]
		else:
			cost = b.cost()
			buy_txt = "+1 (%.0fP)" % cost

		var btn_style = "green" if bal >= cost else "grey"
		_draw_button(Rect2(CARD_X + CARD_W - 148, card_y + 12, 138, 54), buy_txt, btn_style, Color.WHITE)

func _draw_upgrade_tab() -> void:
	var upgs = engine_ref.upgrades
	var bal = engine_ref.wallet.balance()
	for i in range(upgs.size()):
		var u = upgs[i]
		var card_y = CONTENT_Y + i * 94
		var card_rect := Rect2(CARD_X, card_y, CARD_W, 86)
		draw_rect(card_rect, Color(0.20, 0.13, 0.08, 1.0), true)

		_draw_business_icon(u.target_business_id, _scaled_rect(Rect2(CARD_X + 8, card_y + 11, 64, 64), _bounce_scale(u.target_business_id)))

		draw_string(_font, Vector2(CARD_X + 82, card_y + 28), u.name, HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 240, 14, Color(1.0, 0.80, 0.15, 1.0))
		draw_string(_font, Vector2(CARD_X + 82, card_y + 52), u.description, HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 240, 11, Color(0.85, 0.80, 0.75, 1.0))

		var txt = "TERBELI" if u.is_purchased else ("BELI %.0fP" % u.cost)
		var style = "blue" if u.is_purchased else ("yellow" if bal >= u.cost else "grey")
		_draw_button(Rect2(CARD_X + CARD_W - 148, card_y + 16, 138, 54), txt, style, Color.BLACK if not u.is_purchased else Color.WHITE)

func _draw_mandor_tab() -> void:
	var mgrs = engine_ref.managers
	var bal = engine_ref.wallet.balance()
	for i in range(mgrs.size()):
		var m = mgrs[i]
		var card_y = CONTENT_Y + i * 94
		var card_rect := Rect2(CARD_X, card_y, CARD_W, 86)
		draw_rect(card_rect, Color(0.20, 0.13, 0.08, 1.0), true)

		_draw_business_icon(m.target_business_id, _scaled_rect(Rect2(CARD_X + 8, card_y + 11, 64, 64), _bounce_scale(m.target_business_id)))

		draw_string(_font, Vector2(CARD_X + 82, card_y + 28), m.name, HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 240, 14, Color(0.70, 0.85, 0.60, 1.0))
		draw_string(_font, Vector2(CARD_X + 82, card_y + 52), m.description, HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 240, 11, Color(0.85, 0.80, 0.75, 1.0))

		var txt = "DIREKRUT" if m.is_hired else ("REKRUT %.0fP" % m.cost)
		var style = "blue" if m.is_hired else ("yellow" if bal >= m.cost else "grey")
		_draw_button(Rect2(CARD_X + CARD_W - 148, card_y + 16, 138, 54), txt, style, Color.BLACK if not m.is_hired else Color.WHITE)

func _draw_prestasi_tab() -> void:
	var achs = engine_ref.achievements
	for i in range(achs.size()):
		var a = achs[i]
		var card_y = CONTENT_Y + i * 94
		var card_rect := Rect2(CARD_X, card_y, CARD_W, 86)
		draw_rect(card_rect, Color(0.20, 0.13, 0.08, 1.0), true)

		draw_string(_font, Vector2(CARD_X + 16, card_y + 30), a.name, HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 200, 14, Color(1.0, 0.80, 0.15, 1.0))
		draw_string(_font, Vector2(CARD_X + 16, card_y + 54), a.description, HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 200, 11, Color(0.85, 0.80, 0.75, 1.0))

		var txt = "TERCAPAI" if a.is_unlocked else "BELUM"
		var style = "green" if a.is_unlocked else "grey"
		_draw_button(Rect2(CARD_X + CARD_W - 148, card_y + 16, 138, 54), txt, style, Color.WHITE)

func _draw_festival_tab() -> void:
	draw_rect(Rect2(CARD_X, CONTENT_Y, CARD_W, 420), Color(0.20, 0.13, 0.08, 1.0), true)
	draw_string(_font, Vector2(CARD_X + 24, CONTENT_Y + 40), "FESTIVAL PANEN RAYA", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.80, 0.15, 1.0))

	draw_string(_font, Vector2(CARD_X + 24, CONTENT_Y + 76), "Gelar festival untuk mereset lahan dan", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(_font, Vector2(CARD_X + 24, CONTENT_Y + 96), "dapatkan Angel Investor permanen.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	var owned = engine_ref.angels
	var claimable = engine_ref.calculate_angels_to_claim()

	draw_string(_font, Vector2(CARD_X + 24, CONTENT_Y + 140), "ANGEL DIMILIKI: %d (+%.0f%%)" % [owned, float(owned) * 5.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.70, 0.85, 0.60, 1.0))
	draw_string(_font, Vector2(CARD_X + 24, CONTENT_Y + 166), "KLAIM ANGEL BARU: +%d" % claimable, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.80, 0.15, 1.0))

	var txt = "KLAIM +%d ANGEL" % claimable if claimable > 0 else "PROGRES BELUM CUKUP"
	var style = "yellow" if claimable > 0 else "grey"
	_draw_button(Rect2(CARD_X + 40, CONTENT_Y + 210, CARD_W - 80, 60), txt, style, Color.BLACK if claimable > 0 else Color.WHITE)

func _draw_business_icon(business_id: String, rect: Rect2) -> void:
	if business_id == "greenhouse":
		if farmexp_tilemap_tex != null:
			draw_texture_rect_region(farmexp_tilemap_tex, rect, GREENHOUSE_SRC)
		return
	if farm_tilemap_tex == null or not FARM_ICON_TILES.has(business_id):
		return
	var index: int = FARM_ICON_TILES[business_id]
	var i := index - 1
	var col := i % 12
	@warning_ignore("integer_division")
	var row := i / 12
	var src := Rect2(col * 17, row * 17, 16, 16)
	draw_texture_rect_region(farm_tilemap_tex, rect, src)

func _draw_button(rect: Rect2, label: String, style: String, txt_color: Color) -> void:
	if _button_styles.has(style):
		draw_style_box(_button_styles[style], rect)
	else:
		draw_rect(rect, Color(0.3, 0.3, 0.3, 1.0), true)
		draw_rect(rect, Color.WHITE, false, 1.0)
	var text_pos = Vector2(rect.position.x + (rect.size.x / 2.0) - (label.length() * 3.5), rect.position.y + (rect.size.y / 2.0) + 4)
	draw_string(_font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, txt_color)
