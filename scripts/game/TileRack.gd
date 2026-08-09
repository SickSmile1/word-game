class_name TileRack
extends RefCounted

var _tiles: String


func _init(tiles: String = ""):
	_tiles = tiles.to_upper()


func get_tiles() -> String:
	return _tiles


func set_tiles(tiles: String) -> void:
	_tiles = tiles.to_upper()


func size() -> int:
	return _tiles.length()


func has_tile(letter: String) -> bool:
	return _tiles.find(letter.to_upper()) >= 0


func add_tiles(tiles: String) -> void:
	_tiles += tiles.to_upper()


func remove_tiles(tiles_to_remove: String) -> bool:
	var upper = tiles_to_remove.to_upper()
	var temp = _tiles
	for c in upper:
		var idx = temp.find(c)
		if idx >= 0:
			temp = temp.left(idx) + temp.substr(idx + 1)
		else:
			return false
	_tiles = temp
	return true


func remove_letter(letter: String) -> bool:
	var idx = _tiles.find(letter.to_upper())
	if idx >= 0:
		_tiles = _tiles.left(idx) + _tiles.substr(idx + 1)
		return true
	return false


func get_letters_as_array() -> Array:
	var arr: Array = []
	for i in range(_tiles.length()):
		arr.append(_tiles[i])
	return arr


func count_letter(letter: String) -> int:
	var upper = letter.to_upper()
	var count := 0
	for c in _tiles:
		if c == upper:
			count += 1
	return count


func is_empty() -> bool:
	return _tiles.length() == 0


func _to_string() -> String:
	return _tiles
