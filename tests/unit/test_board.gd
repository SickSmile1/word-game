extends GutTest

const Board = preload("res://scripts/game/Board.gd")

var _board: Board


func before_each() -> void:
	_board = autofree(Board.new())


func test_new_board_is_empty() -> void:
	assert_true(_board.is_first_move())
	assert_eq(_board.get_tile(7, 7), "")


func test_place_and_get_tile() -> void:
	_board.place_tile(7, 7, "A")
	assert_eq(_board.get_tile(7, 7), "A")


func test_is_occupied() -> void:
	assert_false(_board.is_occupied(7, 7))
	_board.place_tile(7, 7, "A")
	assert_true(_board.is_occupied(7, 7))


func test_remove_tile() -> void:
	_board.place_tile(7, 7, "A")
	_board.remove_tile(7, 7)
	assert_false(_board.is_occupied(7, 7))


func test_clear_board() -> void:
	_board.place_tile(7, 7, "A")
	_board.place_tile(0, 0, "B")
	_board.clear()
	assert_true(_board.is_first_move())


func test_get_center() -> void:
	var center = _board.get_center()
	assert_eq(center.x, 7)
	assert_eq(center.y, 7)


func test_anchors_on_empty_board_is_only_center() -> void:
	var anchors = _board.get_anchors()
	assert_eq(anchors.size(), 1)
	assert_eq(anchors[0], Vector2i(7, 7))


func test_anchors_after_placing_tile() -> void:
	_board.place_tile(7, 7, "A")
	var anchors = _board.get_anchors()
	assert_gt(anchors.size(), 1)
	var found = false
	for a in anchors:
		if a == Vector2i(7, 6):
			found = true
	assert_true(found)


func test_anchors_dont_include_occupied_squares() -> void:
	_board.place_tile(7, 7, "A")
	var anchors = _board.get_anchors()
	var found = anchors.has(Vector2i(7, 7))
	assert_false(found)


func test_is_first_move() -> void:
	assert_true(_board.is_first_move())
	_board.place_tile(0, 0, "X")
	assert_false(_board.is_first_move())


func test_get_bonus_squares() -> void:
	assert_eq(_board.get_bonus(0, 0), 4)
	assert_eq(_board.get_bonus(0, 3), 1)
	assert_eq(_board.get_bonus(1, 1), 3)
	assert_eq(_board.get_bonus(1, 5), 2)
	assert_eq(_board.get_bonus(7, 7), 0)


func test_get_existing_word_horizontal() -> void:
	_board.place_tile(7, 6, "C")
	_board.place_tile(7, 7, "A")
	_board.place_tile(7, 8, "T")
	var result = _board.get_existing_word(7, 6, true)
	assert_eq(result.word, "CAT")
	assert_eq(result.row, 7)
	assert_eq(result.col, 6)


func test_get_existing_word_vertical() -> void:
	_board.place_tile(6, 7, "C")
	_board.place_tile(7, 7, "A")
	_board.place_tile(8, 7, "T")
	var result = _board.get_existing_word(7, 7, false)
	assert_eq(result.word, "CAT")
	assert_eq(result.row, 6)
	assert_eq(result.col, 7)


func test_is_move_connected_first_move() -> void:
	var tiles_placed = [Vector2i(7, 7)]
	assert_true(_board.is_move_connected(7, 7, true, tiles_placed))


func test_is_move_connected_not_center_fails_first_move() -> void:
	var tiles_placed = [Vector2i(7, 6)]
	assert_false(_board.is_move_connected(7, 6, true, tiles_placed))


func test_is_move_connected_adjacent_to_existing() -> void:
	_board.place_tile(7, 7, "A")
	var tiles_placed = [Vector2i(7, 6)]
	assert_true(_board.is_move_connected(7, 6, true, tiles_placed))


func test_is_move_connected_not_adjacent() -> void:
	_board.place_tile(7, 7, "A")
	var tiles_placed = [Vector2i(5, 5)]
	assert_false(_board.is_move_connected(5, 5, true, tiles_placed))
