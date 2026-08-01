class_name IdleSaveManager
extends RefCounted

const SAVE_PATH: String = "user://savegame.json"
const XOR_KEY: int = 0xAB

static func save_game(engine: RefCounted) -> bool:
	var state: Dictionary = engine.export_state()
	var json_str: String = JSON.stringify(state)
	var bytes: PackedByteArray = json_str.to_utf8_buffer()

	# XOR Obfuscation
	for i in range(bytes.size()):
		bytes[i] = bytes[i] ^ XOR_KEY

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true

static func load_game(engine: RefCounted) -> float:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0.0

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return 0.0

	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	if bytes.size() == 0:
		return 0.0

	# Check if XOR obfuscated or plain JSON
	var is_plain: bool = false
	if bytes[0] == 123: # '{'
		is_plain = true

	if not is_plain:
		for i in range(bytes.size()):
			bytes[i] = bytes[i] ^ XOR_KEY

	var json_str: String = bytes.get_string_from_utf8()
	var state = JSON.parse_string(json_str)

	if typeof(state) != TYPE_DICTIONARY:
		return 0.0

	return engine.import_state(state)
