class_name Scoring
extends RefCounted

const Board = preload("res://scripts/game/Board.gd")
const Tiles = preload("res://scripts/game/Tiles.gd")


static func calculate(
	board, word: String, row: int, col: int, horizontal: bool, tiles_placed: Array
) -> int:
	var placed_set: Dictionary = {}
	for p in tiles_placed:
		placed_set[p] = true

	# Temporarily place tiles on the board if they are not already occupied
	var placed_temporarily: Array = []
	var dr = 0 if horizontal else 1
	var dc = 1 if horizontal else 0
	var r = row
	var c = col
	for i in range(word.length()):
		var pos = Vector2i(r, c)
		if placed_set.has(pos):
			if not board.is_occupied(pos.x, pos.y):
				board.place_tile(pos.x, pos.y, word[i])
				placed_temporarily.append(pos)
		r += dr
		c += dc

	r = row
	c = col
	var total := 0
	var word_multiplier := 1

	for i in range(word.length()):
		var letter = word[i]
		var is_new = placed_set.has(Vector2i(r, c))
		var bonus = board.get_bonus(r, c) if is_new else Board.BONUS_NONE
		var letter_value = Tiles.get_value(letter)

		match bonus:
			Board.BONUS_DL:
				letter_value *= 2
			Board.BONUS_TL:
				letter_value *= 3
			Board.BONUS_DW:
				word_multiplier *= 2
			Board.BONUS_TW:
				word_multiplier *= 3

		total += letter_value
		r += dr
		c += dc

	total *= word_multiplier

	var cross_score := 0
	var nr = row
	var nc = col
	for i in range(word.length()):
		if placed_set.has(Vector2i(nr, nc)):
			cross_score += _calculate_cross(board, nr, nc, horizontal)
		nr += dr
		nc += dc

	total += cross_score

	if tiles_placed.size() == 7:
		total += 50

	# Clean up temporarily placed tiles
	for p in placed_temporarily:
		board.remove_tile(p.x, p.y)

	return total


static func _calculate_cross(board, row: int, col: int, horizontal: bool) -> int:
	var perp_dr = 1 if horizontal else 0
	var perp_dc = 0 if horizontal else 1

	var r = row - perp_dr
	var c = col - perp_dc
	while r >= 0 and c >= 0 and r < Board.SIZE and c < Board.SIZE and board.is_occupied(r, c):
		r -= perp_dr
		c -= perp_dc

	r += perp_dr
	c += perp_dc

	if not board.is_occupied(r, c):
		return 0

	var word := ""
	var positions: Array = []
	while r >= 0 and c >= 0 and r < Board.SIZE and c < Board.SIZE and board.is_occupied(r, c):
		word += board.get_tile(r, c)
		positions.append(Vector2i(r, c))
		r += perp_dr
		c += perp_dc

	if word.length() < 2:
		return 0

	var score := 0
	var word_mult := 1
	for p in positions:
		var lv = Tiles.get_value(board.get_tile(p.x, p.y))
		var is_new = (p.x == row and p.y == col)
		var bonus = board.get_bonus(p.x, p.y) if is_new else Board.BONUS_NONE
		match bonus:
			Board.BONUS_DL:
				lv *= 2
			Board.BONUS_TL:
				lv *= 3
			Board.BONUS_DW:
				word_mult *= 2
			Board.BONUS_TW:
				word_mult *= 3
		score += lv
	score *= word_mult
	return score


static func _is_position_in(positions: Array, row: int, col: int) -> bool:
	for p in positions:
		if p.x == row and p.y == col:
			return true
	return false
