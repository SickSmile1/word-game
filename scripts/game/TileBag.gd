class_name TileBag
extends RefCounted

const Tiles = preload("res://scripts/game/Tiles.gd")

var _pool: Array[String]


func _init():
	_pool = []
	for letter in Tiles.DISTRIBUTION:
		var count = Tiles.DISTRIBUTION[letter]
		for j in range(count):
			_pool.append(letter)
	_pool.shuffle()


func draw_tile() -> String:
	if _pool.is_empty():
		return ""
	return _pool.pop_back()


func draw_tiles(count: int) -> String:
	var result := ""
	for i in range(count):
		var t = draw_tile()
		if t.is_empty():
			break
		result += t
	return result


func exchange(returned: String) -> String:
	for c in returned:
		_pool.append(c.to_upper())
	_pool.shuffle()
	return draw_tiles(returned.length())


func remaining() -> int:
	return _pool.size()


func is_empty() -> bool:
	return _pool.is_empty()


func draw_balanced_tiles(count: int) -> String:
	var vowels := "AEIOUÄÖÜ"

	for attempt in range(20):
		var result := ""
		var vowel_count := 0
		var consonant_count := 0

		for i in range(count):
			var tile = draw_tile()
			if tile.is_empty():
				break
			result += tile
			if vowels.contains(tile):
				vowel_count += 1
			else:
				consonant_count += 1

		if (vowel_count >= 2 and consonant_count >= 2) or remaining() < count:
			return result

		# Put them back and shuffle for another attempt
		for c in result:
			_pool.append(c)
		_pool.shuffle()

	# Fallback draw
	var result := ""
	for i in range(count):
		var tile = draw_tile()
		if tile.is_empty():
			break
		result += tile
	return result
