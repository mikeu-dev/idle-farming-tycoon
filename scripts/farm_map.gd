extends Node2D

class_name FarmMap

# kenney_tiny-farm/Tilesheet.txt: 16x16px tiles, 1px spacing, 12 cols x 11 rows
const TILE_PX := 16
const TILE_SPACING := 1
const TILEMAP_COLS := 12
const SOIL_TILE_INDEX := 49 # plowed dirt tile (verified visually)

var engine_ref: IdleEngine

# Clickable farm zones
var farm_zones = [
	{"id": "corn", "rect": Rect2(30, 125, 475, 100)},
	{"id": "wheat", "rect": Rect2(30, 245, 475, 100)},
	{"id": "livestock", "rect": Rect2(30, 365, 475, 100)},
	{"id": "greenhouse", "rect": Rect2(30, 485, 475, 100)},
	{"id": "processing", "rect": Rect2(30, 605, 475, 100)}
]

# Kenney Tile textures
var farm_tilemap_tex: Texture2D
var town_tilemap_tex: Texture2D
var _font: Font = ThemeDB.fallback_font

func _ready() -> void:
	# Load pre-packaged tilemaps
	if ResourceLoader.exists("res://assets/kenney_tiny-farm/Tilemap/tilemap_packed.png"):
		farm_tilemap_tex = load("res://assets/kenney_tiny-farm/Tilemap/tilemap_packed.png")
	if ResourceLoader.exists("res://assets/kenney_tiny-town/Tilemap/tilemap_packed.png"):
		town_tilemap_tex = load("res://assets/kenney_tiny-town/Tilemap/tilemap_packed.png")
	if ResourceLoader.exists("res://assets/kenney_ui-pack/Font/Kenney Future.ttf"):
		_font = load("res://assets/kenney_ui-pack/Font/Kenney Future.ttf")

func setup(eng: IdleEngine) -> void:
	engine_ref = eng

## Returns the source Rect2 (in pixels) of a 1-indexed tile within tilemap_packed.png,
## computed from the sheet layout instead of loading 132 separate tile files.
func _tile_region(index: int) -> Rect2:
	var i := index - 1
	var col := i % TILEMAP_COLS
	@warning_ignore("integer_division")
	var row := i / TILEMAP_COLS
	var x := col * (TILE_PX + TILE_SPACING)
	var y := row * (TILE_PX + TILE_SPACING)
	return Rect2(x, y, TILE_PX, TILE_PX)

func _process(_delta: float) -> void:
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = event.position
		for zone in farm_zones:
			if zone["rect"].has_point(pos):
				if engine_ref != null:
					engine_ref.trigger_production_by_id(zone["id"])
				break

func _draw() -> void:
	# 1. Map Base Window Background Frame
	var map_rect = Rect2(20, 95, 495, 635)
	draw_rect(map_rect, Color(0.14, 0.25, 0.12, 1.0), true)
	draw_rect(map_rect, Color(0.55, 0.76, 0.29, 1.0), false, 3.0)

	# Title Banner
	draw_rect(Rect2(20, 95, 495, 26), Color(0.08, 0.11, 0.07, 1.0), true)
	draw_string(_font, Vector2(35, 114), "DUNIA PERTANIAN 2D (GODOT 4 ENGINE)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.76, 0.03, 1.0))

	if engine_ref == null:
		return

	# 2. Render 5 Farm Plot Zones
	var mouse_pos = get_local_mouse_position()

	for zone in farm_zones:
		var z_id = zone["id"]
		var z_rect = zone["rect"]

		var biz: IdleBusiness = null
		for b in engine_ref.businesses:
			if b.id == z_id:
				biz = b
				break

		if biz == null:
			continue

		# Hover outline
		if z_rect.has_point(mouse_pos):
			draw_rect(z_rect.grow(2), Color(1.0, 0.84, 0.0, 1.0), false, 2.0)

		# Draw Soil Bed Base (Plowed Soil) — tiled texture from tiny-farm tilemap
		var soil_src := _tile_region(SOIL_TILE_INDEX)
		for row in range(2):
			for col in range(4):
				var tx = z_rect.position.x + 10 + col * 40
				var ty = z_rect.position.y + 10 + row * 40
				if farm_tilemap_tex != null:
					draw_texture_rect_region(farm_tilemap_tex, Rect2(tx, ty, 38, 38), soil_src)
				else:
					draw_rect(Rect2(tx, ty, 38, 38), Color(0.40, 0.26, 0.13, 1.0), true)

		# Zone Label & Level
		var status_str = "%s (LVL %d)" % [biz.name, biz.level]
		if not biz.is_owned():
			status_str = "%s [BELUM DIBELI]" % biz.name

		draw_string(_font, Vector2(z_rect.position.x + 230, z_rect.position.y + 26), status_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

		# Progress Bar
		var prog_ratio = biz.get_progress_ratio()
		var bar_rect = Rect2(z_rect.position.x + 230, z_rect.position.y + 42, 235, 18)
		draw_rect(bar_rect, Color(0.07, 0.09, 0.06, 1.0), true)
		if prog_ratio > 0.0:
			var fill_rect = Rect2(z_rect.position.x + 230, z_rect.position.y + 42, 235.0 * prog_ratio, 18)
			draw_rect(fill_rect, Color(0.30, 0.69, 0.31, 1.0), true)

		var prog_txt = "%.0f%%" % (prog_ratio * 100.0)
		draw_string(_font, Vector2(z_rect.position.x + 330, z_rect.position.y + 55), prog_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

		# Action Hint
		var action_hint = "👉 KLIK UNTUK PANEN"
		if biz.is_automated:
			action_hint = "⚙️ OTOMATISASI PANEN"
		elif not biz.is_owned():
			action_hint = "🔒 BELI LAHAN DI PANEL KANAN"
		draw_string(_font, Vector2(z_rect.position.x + 230, z_rect.position.y + 82), action_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.76, 0.03, 1.0))
