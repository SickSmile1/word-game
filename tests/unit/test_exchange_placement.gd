extends GutTest

const Board = preload("res://scripts/game/Board.gd")
const TileRack = preload("res://scripts/game/TileRack.gd")
const TileBag = preload("res://scripts/game/TileBag.gd")


func test_board_cell_can_be_empty():
	var board = autofree(Board.new())
	# Verify initial board is empty
	assert_true(board.is_empty_at(7, 7), "Center cell should be empty")


func test_board_cell_can_be_occupied():
	var board = autofree(Board.new())
	board.place_tile(7, 7, "A")
	assert_false(board.is_empty_at(7, 7), "Cell with tile should not be empty")
	assert_eq(board.get_tile(7, 7), "A", "Cell should contain placed tile")


func test_tile_rack_add_remove():
	var bag = autofree(TileBag.new())
	var rack = autofree(TileRack.new("ABC"))

	assert_eq(rack.get_tiles(), "ABC", "Rack should contain initial tiles")

	rack.remove_letter("B")
	assert_eq(rack.get_tiles(), "AC", "Rack should have B removed")

	rack.add_tiles("X")
	assert_eq(rack.get_tiles(), "ACX", "Rack should have X added")


func test_exchange_bag_functionality():
	var bag = autofree(TileBag.new())

	# Draw initial tiles
	var initial = bag.draw_tiles(7)
	var initial_remaining = bag.remaining()

	# Exchange some tiles
	var returned = "ABC"
	var new_tiles = bag.exchange(returned)

	assert_eq(new_tiles.length(), returned.length(), "Exchange should return same number of tiles")
	assert_eq(bag.remaining(), initial_remaining, "Remaining tiles should be same after exchange")


func test_multiple_tile_placements():
	var board = autofree(Board.new())

	# Place first tile
	board.place_tile(7, 7, "C")
	assert_eq(board.get_tile(7, 7), "C")

	# Place second tile
	board.place_tile(7, 8, "A")
	assert_eq(board.get_tile(7, 8), "A")

	# Place third tile
	board.place_tile(7, 9, "T")
	assert_eq(board.get_tile(7, 9), "T")

	# Verify all three are placed
	assert_eq(board.get_tile(7, 7), "C")
	assert_eq(board.get_tile(7, 8), "A")
	assert_eq(board.get_tile(7, 9), "T")


func test_board_is_occupied_correct():
	var board = autofree(Board.new())

	# Initially empty
	assert_false(board.is_occupied(7, 7))

	# Place a tile
	board.place_tile(7, 7, "A")

	# Now occupied
	assert_true(board.is_occupied(7, 7))
	assert_false(board.is_occupied(7, 8))


func test_tile_placement_across_board():
	var board = autofree(Board.new())

	# Place tiles in various positions
	var positions := [
		Vector2i(0, 0),
		Vector2i(7, 7),
		Vector2i(14, 14),
		Vector2i(7, 0),
		Vector2i(0, 14),
		Vector2i(5, 10),
	]

	for pos in positions:
		board.place_tile(pos.x, pos.y, "X")
		assert_eq(
			board.get_tile(pos.x, pos.y), "X", "Tile should be placed at (%d,%d)" % [pos.x, pos.y]
		)
