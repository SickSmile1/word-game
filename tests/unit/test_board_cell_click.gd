extends GutTest

const Board = preload("res://scripts/game/Board.gd")


func test_board_placement_sequence():
	var board = autofree(Board.new())

	# Verify center is empty
	assert_true(board.is_empty_at(7, 7), "Center should be empty initially")

	# Place first tile
	board.place_tile(7, 7, "C")
	assert_false(board.is_empty_at(7, 7), "Center should be occupied after placement")
	assert_eq(board.get_tile(7, 7), "C", "Center should contain C")

	# Place second tile adjacent
	board.place_tile(7, 8, "A")
	assert_eq(board.get_tile(7, 8), "A", "Adjacent cell should contain A")

	# Place third tile
	board.place_tile(7, 9, "T")
	assert_eq(board.get_tile(7, 9), "T", "Third cell should contain T")

	# Verify all placements
	assert_eq(board.get_tile(7, 7), "C")
	assert_eq(board.get_tile(7, 8), "A")
	assert_eq(board.get_tile(7, 9), "T")

	# Verify cells are occupied
	assert_true(board.is_occupied(7, 7))
	assert_true(board.is_occupied(7, 8))
	assert_true(board.is_occupied(7, 9))

	# Verify adjacent empty cells
	assert_true(board.is_empty_at(7, 6))
	assert_true(board.is_empty_at(7, 10))


func test_board_placement_various_positions():
	var board = autofree(Board.new())

	var placements = [
		{"row": 0, "col": 0, "letter": "A"},
		{"row": 7, "col": 7, "letter": "B"},
		{"row": 14, "col": 14, "letter": "C"},
		{"row": 7, "col": 0, "letter": "D"},
		{"row": 0, "col": 7, "letter": "E"},
	]

	for p in placements:
		board.place_tile(p["row"], p["col"], p["letter"])
		assert_eq(
			board.get_tile(p["row"], p["col"]),
			p["letter"],
			"Placement at (%d,%d) should succeed" % [p["row"], p["col"]]
		)
		assert_true(board.is_occupied(p["row"], p["col"]))


func test_board_tile_validity():
	var board = autofree(Board.new())

	# Place tiles
	board.place_tile(5, 5, "T")
	board.place_tile(5, 6, "E")
	board.place_tile(5, 7, "S")
	board.place_tile(5, 8, "T")

	# Verify sequence
	assert_eq(board.get_tile(5, 5), "T")
	assert_eq(board.get_tile(5, 6), "E")
	assert_eq(board.get_tile(5, 7), "S")
	assert_eq(board.get_tile(5, 8), "T")

	# Verify empty cells remain empty
	assert_true(board.is_empty_at(5, 4))
	assert_true(board.is_empty_at(5, 9))
