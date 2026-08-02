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

# Decorative trees scattered around the field grid to sell "outdoor world"
# rather than empty space between tiles. Positions picked by eye to sit in
# the gaps between/around the grid (see _zone_rect for the grid math).
# tile 16 = tall pine, tile 28 = round bush tree (both verified visually).
var _trees := [
	{"pos": Vector2(40, 110), "tile": 16, "scale": 1.1},
	{"pos": Vector2(680, 130), "tile": 28, "scale": 1.0},
	{"pos": Vector2(360, 96), "tile": 28, "scale": 0.8},
	{"pos": Vector2(30, 470), "tile": 28, "scale": 1.0},
	{"pos": Vector2(690, 500), "tile": 16, "scale": 1.15},
	{"pos": Vector2(70, 660), "tile": 16, "scale": 0.9},
	{"pos": Vector2(660, 680), "tile": 28, "scale": 1.05},
]

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

## A deterministic wobbly-edged blob (not a rectangle) so field patches read
## as irregular ground rather than UI cards. seed_offset varies the shape.
func _organic_polygon(center: Vector2, radius: Vector2, seed_offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var n := 12
	for i in range(n):
		var angle: float = TAU * i / n
		var jitter: float = 0.86 + 0.14 * sin(angle * 3.0 + seed_offset) + 0.06 * cos(angle * 5.0 - seed_offset)
		points.append(center + Vector2(cos(angle) * radius.x * jitter, sin(angle) * radius.y * jitter))
	return points

func _draw_grass_base(rect: Rect2, seed_offset: float) -> void:
	var center: Vector2 = rect.position + rect.size / 2.0
	var radius: Vector2 = rect.size / 2.0 + Vector2(18, 18)
	var poly := _organic_polygon(center, radius, seed_offset)
	draw_colored_polygon(poly, Color(0.24, 0.42, 0.18, 1.0))
	var poly_inner := _organic_polygon(center, radius - Vector2(6, 6), seed_offset)
	draw_colored_polygon(poly_inner, Color(0.32, 0.54, 0.24, 1.0))

func _draw_tree(pos: Vector2, tile_index: int, tree_scale: float) -> void:
	if farm_tilemap_tex == null:
		return
	var size := Vector2(40, 40) * tree_scale
	draw_texture_rect_region(farm_tilemap_tex, Rect2(pos - size / 2.0, size), _tile_region(tile_index))

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

## Small circular badge popping over a tile corner, showing the field's level.
func _draw_level_badge(top_left: Vector2, level: int) -> void:
	var r := 16.0
	var badge_center := top_left + Vector2(r, r)
	draw_circle(badge_center, r, Color(0.20, 0.35, 0.55, 1.0))
	draw_circle(badge_center, r, Color(0.05, 0.05, 0.05, 0.6), false, 2.0)
	draw_string(_font, badge_center + Vector2(-9, 5), str(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

## Small "automated" badge for fields that no longer need a tap.
func _draw_auto_badge(center: Vector2) -> void:
	draw_circle(center, 12.0, Color(0.35, 0.65, 0.85, 1.0))
	draw_circle(center, 12.0, Color(0.05, 0.05, 0.05, 0.5), false, 2.0)
	draw_string(_font, center + Vector2(-9, 4), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

## Floating call-to-action chip (e.g. "TANAM!") overlaid on the field, like a
## collect prompt hovering over the object it applies to.
func _draw_action_bubble(center: Vector2, text: String) -> void:
	var w: float = 20.0 + text.length() * 8.0
	var rect := Rect2(center.x - w / 2.0, center.y - 15.0, w, 30.0)
	draw_rect(rect, Color(1.0, 0.80, 0.15, 0.95), true)
	draw_rect(rect, Color(0.16, 0.10, 0.06, 1.0), false, 2.0)
	draw_string(_font, Vector2(rect.position.x + 10, rect.position.y + 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.16, 0.10, 0.06, 1.0))

## Wooden sign-style tag for locked fields, showing the unlock cost.
func _draw_sign_badge(center: Vector2, text: String) -> void:
	var w: float = 20.0 + text.length() * 7.0
	var rect := Rect2(center.x - w / 2.0, center.y - 13.0, w, 26.0)
	draw_rect(rect, Color(0.85, 0.68, 0.42, 1.0), true)
	draw_rect(rect, Color(0.35, 0.22, 0.12, 1.0), false, 2.0)
	draw_string(_font, Vector2(rect.position.x + 8, rect.position.y + 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.25, 0.15, 0.08, 1.0))

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

	# Full-bleed grass so the world reads as one continuous field, not
	# rectangles floating over empty space.
	draw_rect(Rect2(0, HUD_HEIGHT, 720, SHEET_Y - HUD_HEIGHT), Color(0.29, 0.50, 0.22, 1.0), true)
	for tree in _trees:
		_draw_tree(tree["pos"], tree["tile"], tree["scale"])

	for zone_i in range(farm_zones.size()):
		var zone: Dictionary = farm_zones[zone_i]
		var z_id: String = zone["id"]
		var z_rect := _zone_rect(zone)

		var biz: IdleBusiness = null
		for b in engine_ref.businesses:
			if b.id == z_id:
				biz = b
				break
		if biz == null:
			continue

		_draw_grass_base(z_rect, float(zone_i) * 1.7)
		_draw_soil_patch(z_rect)

		var center: Vector2 = z_rect.position + z_rect.size / 2.0

		if not biz.is_owned():
			draw_rect(z_rect, Color(0.05, 0.05, 0.05, 0.55), true)
			_draw_lock_icon(center - Vector2(0, 14), 30.0)
			_draw_sign_badge(Vector2(center.x, z_rect.position.y + z_rect.size.y - 22), "BELI %.0fP" % biz.cost())
			continue

		# Business icon, big, in the upper part of the tile, with a tap-pop bounce.
		var icon_data := _business_icon_src(z_id)
		var icon_tex: Texture2D = icon_data[0]
		var icon_center := Vector2(center.x, z_rect.position.y + z_rect.size.y * 0.42)
		if icon_tex != null:
			var base_icon_size := Vector2(84, 84) if z_id != "greenhouse" else Vector2(108, 78)
			var icon_scale: float = _tap_scale(z_id)
			var icon_size: Vector2 = base_icon_size * icon_scale
			draw_texture_rect_region(icon_tex, Rect2(icon_center - icon_size / 2.0, icon_size), icon_data[1])

		# Level badge, popping over the tile's top-left corner.
		_draw_level_badge(z_rect.position + Vector2(2, 2), biz.level)

		if biz.is_automated:
			_draw_auto_badge(Vector2(z_rect.position.x + z_rect.size.x - 18, z_rect.position.y + 18))
		elif not biz.is_producing:
			_draw_action_bubble(Vector2(center.x, z_rect.position.y + z_rect.size.y * 0.68), "TANAM!")

		# Progress bar, floating near the bottom of the soil (no separate info panel).
		var prog_ratio: float = _displayed_progress.get(z_id, 0.0)
		var bar_rect := Rect2(z_rect.position.x + 20, z_rect.position.y + z_rect.size.y - 22, z_rect.size.x - 40, 8)
		draw_rect(bar_rect, Color(0.10, 0.07, 0.05, 0.85), true)
		if prog_ratio > 0.0:
			draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * prog_ratio, bar_rect.size.y)), Color(0.45, 0.80, 0.35, 1.0), true)
