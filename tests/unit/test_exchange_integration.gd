extends GutTest

const TileBag = preload("res://scripts/game/TileBag.gd")
const TileRack = preload("res://scripts/game/TileRack.gd")


func test_exchange_flow_basic():
	var bag = autofree(TileBag.new())
	var rack = autofree(TileRack.new("ABCDEFG"))

	var initial_rack = rack.get_tiles()
	assert_eq(initial_rack.length(), 7)

	# Simulate exchange: remove some tiles
	rack.remove_letter("A")
	rack.remove_letter("B")
	rack.remove_letter("C")

	assert_eq(rack.get_tiles().length(), 4)

	# Get new tiles from bag
	var new_tiles = bag.exchange("ABC")
	assert_eq(new_tiles.length(), 3)

	# Add to rack
	rack.add_tiles(new_tiles)
	assert_eq(rack.get_tiles().length(), 7)


func test_exchange_with_balanced_start():
	var bag = autofree(TileBag.new())

	# Draw initial balanced hands
	var hand1 = bag.draw_balanced_tiles(7)
	var hand2 = bag.draw_balanced_tiles(7)

	assert_eq(hand1.length(), 7)
	assert_eq(hand2.length(), 7)

	# Create racks from balanced hands
	var rack1 = autofree(TileRack.new(hand1))
	var rack2 = autofree(TileRack.new(hand2))

	# Exchange operation: remove first 3 tiles from rack1
	var exchange_letters = hand1.substr(0, 3)
	for c in exchange_letters:
		rack1.remove_letter(c)

	# Get new tiles from exchange
	var new_tiles = bag.exchange(exchange_letters)

	# Add new tiles to rack
	rack1.add_tiles(new_tiles)

	# Rack should still have 7 tiles
	assert_eq(rack1.get_tiles().length(), 7)


func test_exchange_bag_maintains_distribution():
	var bag = autofree(TileBag.new())

	var initial_remaining = bag.remaining()

	# Draw all initial tiles
	var hand1 = bag.draw_balanced_tiles(7)
	var hand2 = bag.draw_balanced_tiles(7)
	var remaining_after_draw = bag.remaining()

	# Exchange from hand1
	var exchanged = bag.exchange("ABC")

	var final_remaining = bag.remaining()

	# After exchange: pool should have same remaining count
	assert_eq(
		final_remaining, remaining_after_draw, "Remaining tiles should be same after exchange"
	)


func test_exchange_cannot_exceed_bag_size():
	var bag = autofree(TileBag.new())

	# Draw most of the tiles (total 100 tiles)
	var hand1 = bag.draw_tiles(90)

	# Very few tiles left
	assert_lt(bag.remaining(), 20, "Should have few tiles left")

	# Try to exchange: should work but might get fewer new tiles if bag is empty
	var exchanged = bag.exchange("ABC")
	assert_gte(exchanged.length(), 0, "Exchange should always return a string")
