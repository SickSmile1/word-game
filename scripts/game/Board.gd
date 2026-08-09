class_name Board
extends RefCounted

const SIZE := 15

const BONUS_NONE := 0
const BONUS_DL := 1
const BONUS_TL := 2
const BONUS_DW := 3
const BONUS_TW := 4

const _BONUS_LAYOUT := [
	[4, 0, 0, 1, 0, 0, 0, 4, 0, 0, 0, 1, 0, 0, 4],
	[0, 3, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 3, 0],
	[0, 0, 3, 0, 0, 0, 1, 0, 1, 0, 0, 0, 3, 0, 0],
	[1, 0, 0, 3, 0, 0, 0, 1, 0, 0, 0, 3, 0, 0, 1],
	[0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0],
	[0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0],
	[0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0],
	[4, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 4],
	[0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0],
	[0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0],
	[0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0],
	[1, 0, 0, 3, 0, 0, 0, 1, 0, 0, 0, 3, 0, 0, 1],
	[0, 0, 3, 0, 0, 0, 1, 0, 1, 0, 0, 0, 3, 0, 0],
	[0, 3, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 3, 0],
	[4, 0, 0, 1, 0, 0, 0, 4, 0, 0, 0, 1, 0, 0, 4],
]

var _cells: Array
var _occupied_count: int = 0


func _init():
	_cells = []
	for i in range(SIZE):
		_cells.append([])
		for j in range(SIZE):
			_cells[i].append(null)


func get_tile(row: int, col: int) -> String:
	if not _is_on_board(row, col):
		return ""
	return _cells[row][col] if _cells[row][col] != null else ""


func is_occupied(row: int, col: int) -> bool:
	if not _is_on_board(row, col):
		return false
	return _cells[row][col] != null


func is_empty_at(row: int, col: int) -> bool:
	return not is_occupied(row, col)


func place_tile(row: int, col: int, letter: String) -> void:
	if _is_on_board(row, col):
		if _cells[row][col] == null:
			_occupied_count += 1
		_cells[row][col] = letter.to_upper()


func remove_tile(row: int, col: int) -> void:
	if _is_on_board(row, col):
		if _cells[row][col] != null:
			_occupied_count -= 1
		_cells[row][col] = null


func clear() -> void:
	for i in range(SIZE):
		for j in range(SIZE):
			_cells[i][j] = null
	_occupied_count = 0


static func get_bonus_at(row: int, col: int) -> int:
	if row < 0 or row >= SIZE or col < 0 or col >= SIZE:
		return BONUS_NONE
	return _BONUS_LAYOUT[row][col]


func get_bonus(row: int, col: int) -> int:
	return get_bonus_at(row, col)


func get_center() -> Vector2i:
	return Vector2i(7, 7)


func is_on_board(row: int, col: int) -> bool:
	return row >= 0 and row < SIZE and col >= 0 and col < SIZE


func _is_on_board(row: int, col: int) -> bool:
	return is_on_board(row, col)


func is_first_move() -> bool:
	return _occupied_count == 0


func get_anchors() -> Array:
	var anchors: Array = []
	if is_first_move():
		anchors.append(get_center())
		return anchors

	for r in range(SIZE):
		for c in range(SIZE):
			if _cells[r][c] != null:
				continue
			if _has_occupied_neighbor(r, c):
				anchors.append(Vector2i(r, c))

	return anchors


func _has_occupied_neighbor(row: int, col: int) -> bool:
	var dirs = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for d in dirs:
		var nr = row + d.x
		var nc = col + d.y
		if _is_on_board(nr, nc) and _cells[nr][nc] != null:
			return true
	return false


func get_existing_word(row: int, col: int, horizontal: bool) -> Dictionary:
	var word = ""
	var start_row = row
	var start_col = col
	var positions: Array = []

	if horizontal:
		while start_col > 0 and _cells[row][start_col - 1] != null:
			start_col -= 1
		var c = start_col
		while c < SIZE and _cells[row][c] != null:
			word += _cells[row][c]
			positions.append(Vector2i(row, c))
			c += 1
	else:
		while start_row > 0 and _cells[start_row - 1][col] != null:
			start_row -= 1
		var r = start_row
		while r < SIZE and _cells[r][col] != null:
			word += _cells[r][col]
			positions.append(Vector2i(r, col))
			r += 1

	return {
		"word": word,
		"row": start_row,
		"col": start_col,
		"positions": positions,
	}


func get_all_words(trie) -> Array:
	var words: Array = []
	var visited: Array = []
	for i in range(SIZE):
		visited.append([])
		for j in range(SIZE):
			visited[i].append(false)

	for r in range(SIZE):
		for c in range(SIZE):
			if _cells[r][c] == null or visited[r][c]:
				continue

			if c + 1 < SIZE and _cells[r][c + 1] != null:
				var w = get_existing_word(r, c, true)
				if w.word.length() > 1:
					words.append(w)
					for p in w.positions:
						visited[p.x][p.y] = true

			if r + 1 < SIZE and _cells[r + 1][c] != null:
				var w = get_existing_word(r, c, false)
				if w.word.length() > 1:
					words.append(w)
					for p in w.positions:
						visited[p.x][p.y] = true

			if visited[r][c] == false:
				visited[r][c] = true

	return words


func is_move_connected(
	move_row: int, move_col: int, move_horizontal: bool, tiles_placed: Array
) -> bool:
	if is_first_move():
		var center = get_center()
		for tp in tiles_placed:
			if tp.x == center.x and tp.y == center.y:
				return true
		return false

	for tp in tiles_placed:
		var dirs = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
		for d in dirs:
			var nr = tp.x + d.x
			var nc = tp.y + d.y
			if _is_on_board(nr, nc) and _cells[nr][nc] != null:
				return true

	return false


func duplicate():
	var b = get_script().new()
	for r in range(SIZE):
		for c in range(SIZE):
			if _cells[r][c] != null:
				b._cells[r][c] = _cells[r][c]
	b._occupied_count = _occupied_count
	return b


func _to_string() -> String:
	var result = ""
	for r in range(SIZE):
		for c in range(SIZE):
			if _cells[r][c] != null:
				result += _cells[r][c] + " "
			else:
				result += ". "
		result += "\n"
	return result
