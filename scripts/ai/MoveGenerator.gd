extends RefCounted

const Scoring = preload("res://scripts/game/Scoring.gd")


class Move:
	var word: String
	var row: int
	var col: int
	var horizontal: bool
	var score: int
	var tiles_placed: Array
	var rack_leave: String

	func _init(w: String, r: int, c: int, h: bool, s: int, t: Array, rl: String):
		word = w
		row = r
		col = c
		horizontal = h
		score = s
		tiles_placed = t
		rack_leave = rl

	func _to_string() -> String:
		return "Move(%s, %d, %d, h=%s, score=%d)" % [word, row, col, str(horizontal), score]


var _move_keys: Dictionary = {}
var _cross_cache: Dictionary = {}


func generate_moves(board, rack: String, trie) -> Array:
	_move_keys = {}
	_cross_cache = {}
	var moves: Array = []
	var upper_rack = rack.to_upper()
	var anchors = board.get_anchors()

	for a in anchors:
		_gen_direction(board, a.x, a.y, upper_rack, trie, moves, true)
		_gen_direction(board, a.x, a.y, upper_rack, trie, moves, false)

	_scoring_sort(moves)
	return moves


func _gen_direction(
	board, row: int, col: int, rack: String, trie, moves: Array, horizontal: bool
) -> void:
	var dr = 0 if horizontal else 1
	var dc = 1 if horizontal else 0

	var back_occ := 0
	var r = row - dr
	var c = col - dc
	while r >= 0 and c >= 0 and r < 15 and c < 15 and board.is_occupied(r, c):
		back_occ += 1
		r -= dr
		c -= dc

	var back_emp := 0
	while (
		r >= 0
		and c >= 0
		and r < 15
		and c < 15
		and not board.is_occupied(r, c)
		and back_emp < rack.length()
	):
		back_emp += 1
		r -= dr
		c -= dc

	for ext in range(back_emp + 1):
		var start_r = row - back_occ * dr - ext * dr
		var start_c = col - back_occ * dc - ext * dc
		_go_direction(
			board,
			start_r,
			start_c,
			row,
			col,
			rack,
			trie,
			trie.root,
			"",
			[],
			false,
			moves,
			horizontal
		)


func _go_direction(
	board,
	row: int,
	col: int,
	anchor_row: int,
	anchor_col: int,
	rack: String,
	trie,
	node,
	word: String,
	tiles_placed: Array,
	placed_any: bool,
	moves: Array,
	horizontal: bool
) -> void:
	var dr = 0 if horizontal else 1
	var dc = 1 if horizontal else 0

	var at_bound := (horizontal and col >= 15) or (not horizontal and row >= 15)
	if at_bound:
		if (
			placed_any
			and node.is_end
			and board.is_move_connected(row, col, horizontal, tiles_placed)
		):
			_register_move(board, word, row, col, horizontal, tiles_placed, moves)
		return

	if board.is_occupied(row, col):
		var letter = board.get_tile(row, col)
		if node.children.has(letter):
			_go_direction(
				board,
				row + dr,
				col + dc,
				anchor_row,
				anchor_col,
				rack,
				trie,
				node.children[letter],
				word + letter,
				tiles_placed,
				placed_any,
				moves,
				horizontal
			)
		return

	if placed_any and node.is_end and board.is_move_connected(row, col, horizontal, tiles_placed):
		_register_move(board, word, row, col, horizontal, tiles_placed, moves)

	for i in range(rack.length()):
		var letter = rack[i]
		if not node.children.has(letter):
			continue
		if not _cross_check(board, row, col, letter, horizontal, trie):
			continue
		var new_rack = rack.left(i) + rack.substr(i + 1)
		var new_positions = tiles_placed.duplicate()
		new_positions.append(Vector2i(row, col))
		_go_direction(
			board,
			row + dr,
			col + dc,
			anchor_row,
			anchor_col,
			new_rack,
			trie,
			node.children[letter],
			word + letter,
			new_positions,
			true,
			moves,
			horizontal
		)

	var anchor_pos = anchor_col if horizontal else anchor_row
	var cur_pos = col if horizontal else row
	if not placed_any and cur_pos < anchor_pos:
		_go_direction(
			board,
			row + dr,
			col + dc,
			anchor_row,
			anchor_col,
			rack,
			trie,
			node,
			word,
			tiles_placed,
			false,
			moves,
			horizontal
		)


func _register_move(
	board, word: String, row: int, col: int, horizontal: bool, tiles_placed: Array, moves: Array
) -> void:
	var dr = 0 if horizontal else 1
	var dc = 1 if horizontal else 0

	var start_r = row - dr
	var start_c = col - dc
	while _is_occupied_on_board_or_placed(board, start_r, start_c, tiles_placed):
		start_r -= dr
		start_c -= dc
	start_r += dr
	start_c += dc

	var actual_word = ""
	var r = start_r
	var c = start_c
	while _is_occupied_on_board_or_placed(board, r, c, tiles_placed):
		if board.is_occupied(r, c):
			actual_word += board.get_tile(r, c)
		else:
			var offset = (r - start_r) * dr + (c - start_c) * dc
			actual_word += word[offset] if offset >= 0 and offset < word.length() else "?"
		r += dr
		c += dc

	if actual_word != word:
		return

	var score = Scoring.calculate(board, word, start_r, start_c, horizontal, tiles_placed)
	var move = Move.new(word, start_r, start_c, horizontal, score, tiles_placed, "")

	var key = "%s_%d_%d_%s" % [move.word, move.row, move.col, str(move.horizontal)]
	if not _move_keys.has(key):
		_move_keys[key] = true
		moves.append(move)


func _is_occupied_on_board_or_placed(board, row: int, col: int, tiles_placed: Array) -> bool:
	if board.is_on_board(row, col) and board.is_occupied(row, col):
		return true
	for tp in tiles_placed:
		if tp.x == row and tp.y == col:
			return true
	return false


func _cross_check(board, row: int, col: int, letter: String, is_horizontal: bool, trie) -> bool:
	var cache_key := Vector2i(row * 15 + col, letter.unicode_at(0) * 2 + int(is_horizontal))
	if _cross_cache.has(cache_key):
		return _cross_cache[cache_key]

	var dr = 1 if is_horizontal else 0
	var dc = 0 if is_horizontal else 1

	var has_perp := false
	var cross := ""

	var r = row - dr
	var c = col - dc
	while board.is_on_board(r, c) and board.is_occupied(r, c):
		cross = board.get_tile(r, c) + cross
		r -= dr
		c -= dc
		has_perp = true

	cross += letter

	r = row + dr
	c = col + dc
	while board.is_on_board(r, c) and board.is_occupied(r, c):
		cross += board.get_tile(r, c)
		r += dr
		c += dc
		has_perp = true

	var result: bool
	if not has_perp or cross.length() == 1:
		result = true
	else:
		result = trie.search(cross)

	_cross_cache[cache_key] = result
	return result


func _scoring_sort(moves: Array) -> void:
	moves.sort_custom(_sort_by_score)


func _sort_by_score(a: Move, b: Move) -> bool:
	return a.score > b.score
