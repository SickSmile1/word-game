extends GutTest

const Board = preload("res://scripts/game/Board.gd")
const Tiles = preload("res://scripts/game/Tiles.gd")
const Scoring = preload("res://scripts/game/Scoring.gd")


func test_tile_values() -> void:
	assert_eq(Tiles.get_value("A"), 1)
	assert_eq(Tiles.get_value("Z"), 3)
	assert_eq(Tiles.get_value("Q"), 10)
	assert_eq(Tiles.get_value("_"), 0)


func test_rack_value() -> void:
	assert_eq(Tiles.get_rack_value("AE"), 2)
	assert_eq(Tiles.get_rack_value("QZ"), 13)


func test_score_simple_word() -> void:
	var board = autofree(Board.new())
	var tiles_placed = [Vector2i(7, 7), Vector2i(7, 8), Vector2i(7, 9)]
	var score = Scoring.calculate(board, "CAT", 7, 7, true, tiles_placed)
	assert_eq(score, 6)


func test_score_with_double_letter() -> void:
	var board = autofree(Board.new())
	var tiles_placed = [Vector2i(0, 3)]
	board.place_tile(0, 3, "C")
	var score = Scoring.calculate(board, "C", 0, 3, true, tiles_placed)
	assert_eq(score, 8)


func test_score_with_triple_word() -> void:
	var board = autofree(Board.new())
	var tiles_placed = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	board.place_tile(0, 0, "C")
	board.place_tile(0, 1, "A")
	board.place_tile(0, 2, "T")
	var score = Scoring.calculate(board, "CAT", 0, 0, true, tiles_placed)
	assert_eq(score, 18)


func test_bingo_bonus() -> void:
	var board = autofree(Board.new())
	var tiles_placed = []
	for i in range(7):
		tiles_placed.append(Vector2i(7, 7 + i))
	var score = Scoring.calculate(board, "ABCDEFG", 7, 7, true, tiles_placed)
	assert_gt(score, 50)


func test_score_cross_word_ignores_existing_tile_bonus() -> void:
	var board = autofree(Board.new())
	# Put an existing tile "T" on the board at a bonus square (7, 11) which is a BONUS_DL
	board.place_tile(7, 11, "T")

	# Place "CA" horizontally starting at (6, 11) -> C is at (6,11), A is at (6,12).
	# This forms "CT" vertically as a cross-word.
	var tiles_placed = [Vector2i(6, 11), Vector2i(6, 12)]

	# Place the new tiles on the board as would be done in Game.gd
	board.place_tile(6, 11, "C")
	board.place_tile(6, 12, "A")

	var score = Scoring.calculate(board, "CA", 6, 11, true, tiles_placed)

	# Main word: "CA" at (6,11) and (6,12). Values: C(4) + A(1)*2 (DL) = 6.
	# Cross word: "CT" at (6,11) and (7,11). Value of T should not be doubled despite BONUS_DL.
	# Cross score: C(4) + T(1) = 5.
	# Total expected: 6 + 5 = 11.
	assert_eq(score, 11, "Should ignore DL bonus on existing tile 'T'")


func test_score_new_tile_bonus_applied() -> void:
	var board = autofree(Board.new())
	# Place "CT" vertically starting at (6, 11).
	# Column 11, Row 7 is BONUS_DL. Both tiles are newly placed.
	var tiles_placed = [Vector2i(6, 11), Vector2i(7, 11)]
	board.place_tile(6, 11, "C")
	board.place_tile(7, 11, "T")

	var score = Scoring.calculate(board, "CT", 6, 11, false, tiles_placed)

	# Main word: "CT". C(4) + T(1)*2 = 6.
	assert_eq(score, 6, "Should apply DL bonus on newly placed tile 'T'")


func test_score_cross_word_calculated_correctly_when_not_placed() -> void:
	var board = autofree(Board.new())
	# Place an existing "T" at (7, 11)
	board.place_tile(7, 11, "T")

	# Move is "CA" starting at (6, 11). We do NOT place C and A on the board beforehand
	# (simulating the AI MoveGenerator scoring step).
	var tiles_placed = [Vector2i(6, 11), Vector2i(6, 12)]

	var score = Scoring.calculate(board, "CA", 6, 11, true, tiles_placed)

	# Expected score: Main "CA" (6 due to DL on A) + Cross "CT" (5) = 11.
	# (Previously this would return 5 because the tiles were not placed on the board).
	assert_eq(
		score,
		11,
		"Should calculate cross word correctly even if new tiles are not placed on board yet"
	)
