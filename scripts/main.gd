extends Node2D

var idle_engine: IdleEngine
var farm_map: FarmMap
var ui_manager: UIManager

var auto_save_timer: float = 0.0

func _ready() -> void:
	print("Menginisialisasi Idle Farming Tycoon (Godot 4)...")

	# Initialize core engine
	idle_engine = IdleEngine.new("res://configs/farming_config.json")

	# Load savegame if present
	var offline_revenue: float = IdleSaveManager.load_game(idle_engine)

	# Get child node references
	farm_map = $FarmMap
	ui_manager = $CanvasLayer/UIManager

	if farm_map != null:
		farm_map.setup(idle_engine)

	if ui_manager != null:
		ui_manager.setup(idle_engine)
		if offline_revenue > 0.0:
			ui_manager.set_notification("SELAMAT DATANG KEMBALI! HASIL OFFLINE: +%.2f POIN" % offline_revenue)

func _process(delta: float) -> void:
	if idle_engine != null:
		idle_engine.update(delta)

	auto_save_timer += delta
	if auto_save_timer >= 5.0:
		auto_save_timer = 0.0
		if idle_engine != null:
			IdleSaveManager.save_game(idle_engine)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if idle_engine != null:
			IdleSaveManager.save_game(idle_engine)
			print("Progres game berhasil disimpan sebelum keluar.")
