extends Node2D

class_name FarmMap

# kenney_tiny-farm/Tilesheet.txt: 16x16px tiles, 1px spacing, 12 cols x 11 rows
const TILE_PX := 16
const TILE_SPACING := 1
const TILEMAP_COLS := 12
const SOIL_TILE_INDEX := 49 # plowed dirt tile (verified visually)

# kenney_pixel-platformer-farm-expansion/Tilesheet.txt: 18x18px tiles, 1px spacing, 16 cols x 7 rows.
# The greenhouse building occupies a 4x3 tile block starting at (col 0, row 4).
const GREENHOUSE_SRC := Rect2(0, 76, 75, 56)

# Portrait layout (see project.godot: 720x1280)
const HUD_HEIGHT := 76
const SHEET_Y := 720

const GRID_MARGIN_X := 16
const COL_GAP := 12
const ROW_GAP := 16
const COL_WIDTH := 338
const ROW_HEIGHT := 190

var engine_ref: IdleEngine

# Field tiles laid out as a 2-column grid; "processing" sits alone, centered, in row 2.
var farm_zones := [
	{"id": "corn", "col": 0, "row": 0},
	{"id": "wheat", "col": 1, "row": 0},
	{"id": "livestock", "col": 0, "row": 1},
	{"id": "greenhouse", "col": 1, "row": 1},
	{"id": "processing", "col": -1, "row": 2}, # col -1 = centered single tile
]

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

func setup(eng: IdleEngine) -> void:
	engine_ref = eng

## Returns the source Rect2 (in pixels) of a 1-indexed tile within tiny-farm's tilemap_packed.png.
func _tile_region(index: int) -> Rect2:
	var i := index - 1
	var col := i % TILEMAP_COLS
	@warning_ignore("integer_division")
	var row := i / TILEMAP_COLS
	var x := col * (TILE_PX + TILE_SPACING)
	var y := row * (TILE_PX + TILE_SPACING)
	return Rect2(x, y, TILE_PX, TILE_PX)

func _zone_rect(zone: Dictionary) -> Rect2:
	var col: int = zone["col"]
	var row: int = zone["row"]
	var y: float = HUD_HEIGHT + 16 + row * (ROW_HEIGHT + ROW_GAP)
	if col == -1:
		var centered_x: float = (720.0 - COL_WIDTH) / 2.0
		return Rect2(centered_x, y, COL_WIDTH, ROW_HEIGHT)
	var x: float = GRID_MARGIN_X + col * (COL_WIDTH + COL_GAP)
	return Rect2(x, y, COL_WIDTH, ROW_HEIGHT)

var _displayed_progress: Dictionary = {} # business id -> smoothed progress ratio, for animated fill

const TAP_BOUNCE_DURATION := 0.18
var _tap_bounce: Dictionary = {} # business id -> remaining time

func _process(delta: float) -> void:
	if engine_ref != null:
		for zone in farm_zones:
			var z_id: String = zone["id"]
			for b in engine_ref.businesses:
				if b.id == z_id:
					var target: float = b.get_progress_ratio()
					var current: float = _displayed_progress.get(z_id, 0.0)
					_displayed_progress[z_id] = current + (target - current) * min(1.0, delta * 10.0)
					break

	for key in _tap_bounce.keys():
		_tap_bounce[key] -= delta
		if _tap_bounce[key] <= 0.0:
			_tap_bounce.erase(key)

	queue_redraw()

func _tap_scale(business_id: String) -> float:
	if not _tap_bounce.has(business_id):
		return 1.0
	var t: float = _tap_bounce[business_id] / TAP_BOUNCE_DURATION
	return 1.0 + sin(t * PI) * 0.12

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = event.position
		for zone in farm_zones:
			if _zone_rect(zone).has_point(pos):
				if engine_ref != null:
					var biz: IdleBusiness = null
					for b in engine_ref.businesses:
						if b.id == zone["id"]:
							biz = b
							break
					if biz != null and biz.is_owned():
						if engine_ref.trigger_production_by_id(zone["id"]):
							_tap_bounce[zone["id"]] = TAP_BOUNCE_DURATION
				break

func _draw_soil_patch(rect: Rect2) -> void:
	var soil_src := _tile_region(SOIL_TILE_INDEX)
	var tile_w := 26.0
	var tile_h := 28.0
	var cols := int(rect.size.x / tile_w)
	var rows := int(rect.size.y / tile_h)
	for row in range(rows):
		for col in range(cols):
			var tx = rect.position.x + col * tile_w
			var ty = rect.position.y + row * tile_h
			if farm_tilemap_tex != null:
				draw_texture_rect_region(farm_tilemap_tex, Rect2(tx, ty, tile_w + 0.5, tile_h + 0.5), soil_src)
			else:
				draw_rect(Rect2(tx, ty, tile_w, tile_h), Color(0.40, 0.26, 0.13, 1.0), true)

func _draw_lock_icon(center: Vector2, size: float) -> void:
	var body_h := size * 0.62
	var body_rect := Rect2(center.x - size / 2.0, center.y - body_h / 2.0 + size * 0.12, size, body_h)
	draw_rect(body_rect, Color(0.92, 0.87, 0.72, 1.0), true)
	draw_arc(Vector2(center.x, body_rect.position.y), size * 0.32, PI, TAU, 16, Color(0.92, 0.87, 0.72, 1.0), size * 0.16)

func _business_icon_src(business_id: String) -> Array:
	# Returns [texture, source_rect] for a business id.
	match business_id:
		"corn":
			return [farm_tilemap_tex, _tile_region(33)]
		"wheat":
			return [farm_tilemap_tex, _tile_region(69)]
		"livestock":
			return [farm_tilemap_tex, _tile_region(122)]
		"greenhouse":
			return [farmexp_tilemap_tex, GREENHOUSE_SRC]
		"processing":
			return [farm_tilemap_tex, _tile_region(92)]
		_:
			return [null, Rect2()]

func _draw() -> void:
	if engine_ref == null:
		return

	for zone in farm_zones:
		var z_id: String = zone["id"]
		var z_rect := _zone_rect(zone)

		var biz: IdleBusiness = null
		for b in engine_ref.businesses:
			if b.id == z_id:
				biz = b
				break
		if biz == null:
			continue

		var soil_rect := Rect2(z_rect.position, Vector2(z_rect.size.x, z_rect.size.y - 52))
		var info_rect := Rect2(z_rect.position.x, soil_rect.position.y + soil_rect.size.y, z_rect.size.x, 52)

		_draw_soil_patch(soil_rect)
		draw_rect(info_rect, Color(0.30, 0.20, 0.12, 1.0), true)
		draw_rect(z_rect, Color(0.16, 0.10, 0.06, 1.0), false, 3.0)

		if not biz.is_owned():
			draw_rect(soil_rect, Color(0.05, 0.05, 0.05, 0.55), true)
			_draw_lock_icon(soil_rect.position + soil_rect.size / 2.0, 30.0)
			draw_string(_font, Vector2(info_rect.position.x + 12, info_rect.position.y + 22), biz.name, HORIZONTAL_ALIGNMENT_LEFT, info_rect.size.x - 24, 13, Color.WHITE)
			draw_string(_font, Vector2(info_rect.position.x + 12, info_rect.position.y + 42), "BELI DI TOKO", HORIZONTAL_ALIGNMENT_LEFT, info_rect.size.x - 24, 11, Color(0.85, 0.70, 0.45, 1.0))
			continue

		# Business icon, big and centered on the soil patch, with a tap-pop bounce.
		var icon_data := _business_icon_src(z_id)
		var icon_tex: Texture2D = icon_data[0]
		if icon_tex != null:
			var base_icon_size := Vector2(88, 88) if z_id != "greenhouse" else Vector2(112, 82)
			var icon_scale: float = _tap_scale(z_id)
			var icon_size: Vector2 = base_icon_size * icon_scale
			var icon_pos: Vector2 = soil_rect.position + soil_rect.size / 2.0 - icon_size / 2.0
			draw_texture_rect_region(icon_tex, Rect2(icon_pos, icon_size), icon_data[1])

		# Name + level
		var name_str = "%s  LV.%d" % [biz.name, biz.level]
		draw_string(_font, Vector2(info_rect.position.x + 12, info_rect.position.y + 20), name_str, HORIZONTAL_ALIGNMENT_LEFT, info_rect.size.x - 24, 13, Color.WHITE)

		if biz.is_automated:
			draw_string(_font, Vector2(info_rect.position.x + 12, info_rect.position.y + 36), "OTOMATIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.60, 0.80, 0.95, 1.0))
		else:
			draw_string(_font, Vector2(info_rect.position.x + 12, info_rect.position.y + 36), "KETUK UNTUK PANEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.80, 0.30, 1.0))

		# Progress bar
		var prog_ratio: float = _displayed_progress.get(z_id, 0.0)
		var bar_rect := Rect2(info_rect.position.x + 12, info_rect.position.y + 42, info_rect.size.x - 24, 8)
		draw_rect(bar_rect, Color(0.12, 0.08, 0.05, 1.0), true)
		if prog_ratio > 0.0:
			draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * prog_ratio, bar_rect.size.y)), Color(0.45, 0.80, 0.35, 1.0), true)
