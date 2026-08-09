extends GutTest

const Board = preload("res://scripts/game/Board.gd")


func test_bonus_labels_display_dl():
	var board = autofree(Board.new())
	# DL positions (light blue) - at (0,3)
	var bonus = board.get_bonus(0, 3)
	assert_eq(bonus, Board.BONUS_DL, "Position (0,3) should be DL")


func test_bonus_labels_display_tl():
	var board = autofree(Board.new())
	# TL positions (blue) - at (1,5)
	var bonus = board.get_bonus(1, 5)
	assert_eq(bonus, Board.BONUS_TL, "Position (1,5) should be TL")


func test_bonus_labels_display_dw():
	var board = autofree(Board.new())
	# DW positions (pink) - at (1,1)
	var bonus = board.get_bonus(1, 1)
	assert_eq(bonus, Board.BONUS_DW, "Position (1,1) should be DW")


func test_bonus_labels_display_tw():
	var board = autofree(Board.new())
	# TW positions (red) - at (0,0)
	var bonus = board.get_bonus(0, 0)
	assert_eq(bonus, Board.BONUS_TW, "Position (0,0) should be TW")


func test_bonus_labels_display_none():
	var board = autofree(Board.new())
	# Regular positions should have BONUS_NONE
	var bonus = board.get_bonus(0, 2)
	assert_eq(bonus, Board.BONUS_NONE, "Position (0,2) should be BONUS_NONE")
