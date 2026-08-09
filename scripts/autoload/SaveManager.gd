extends Node

const MAX_SLOTS := 5
const SAVE_DIR := "user://saves/"

var pending_load_slot: int = -1


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func save_data(slot: int, data: Dictionary) -> bool:
	var path = SAVE_DIR + "slot_%d.sav" % slot
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open %s for writing" % path)
		return false
	var json = JSON.stringify(data, "\t")
	file.store_string(json)
	return true


func load_data(slot: int) -> Dictionary:
	var path = SAVE_DIR + "slot_%d.sav" % slot
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json = file.get_as_text()
	var parsed = JSON.parse_string(json)
	if parsed is Dictionary:
		return parsed
	return {}


func get_save_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(MAX_SLOTS):
		var data = load_data(i)
		if data.is_empty():
			continue
		(
			result
			. append(
				{
					"slot": i,
					"difficulty": data.get("difficulty_name", "Unknown"),
					"timestamp": data.get("timestamp", ""),
					"difficulty_num": data.get("difficulty", 0),
					"human_score": data.get("human_score", 0),
					"ai_score": data.get("ai_score", 0),
				}
			)
		)
	result.sort_custom(func(a, b): return a.timestamp > b.timestamp)
	return result


func has_save(slot: int) -> bool:
	var path = SAVE_DIR + "slot_%d.sav" % slot
	return FileAccess.file_exists(path)


func delete_save(slot: int) -> void:
	var path = SAVE_DIR + "slot_%d.sav" % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
