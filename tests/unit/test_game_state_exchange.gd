extends GutTest

const Tiles = preload("res://scripts/game/Tiles.gd")
const TileBag = preload("res://scripts/game/TileBag.gd")
const TileRack = preload("res://scripts/game/TileRack.gd")


func test_initial_racks_are_balanced():
	var bag = autofree(TileBag.new())

	# Simulate game start with balanced draws
	var human_rack_tiles = bag.draw_balanced_tiles(7)
	var ai_rack_tiles = bag.draw_balanced_tiles(7)

	assert_eq(human_rack_tiles.length(), 7, "Human should get 7 tiles")
	assert_eq(ai_rack_tiles.length(), 7, "AI should get 7 tiles")

	# Check human rack is balanced
	var human_vowels = _count_vowels(human_rack_tiles)
	var human_consonants = _count_consonants(human_rack_tiles)
	assert_gte(human_vowels, 2, "Human should have at least 2 vowels")
	assert_gte(human_consonants, 2, "Human should have at least 2 consonants")

	# Check AI rack is balanced
	var ai_vowels = _count_vowels(ai_rack_tiles)
	var ai_consonants = _count_consonants(ai_rack_tiles)
	assert_gte(ai_vowels, 2, "AI should have at least 2 vowels")
	assert_gte(ai_consonants, 2, "AI should have at least 2 consonants")


func test_exchange_does_not_lose_tiles():
	var bag = autofree(TileBag.new())
	var rack = autofree(TileRack.new("ABCDEFG"))

	var total_before = bag.remaining() + rack.get_tiles().length()

	# Exchange tiles
	var exchanged_tiles = "ABC"
	for c in exchanged_tiles:
		rack.remove_letter(c)

	var new_tiles = bag.exchange(exchanged_tiles)
	rack.add_tiles(new_tiles)

	var total_after = bag.remaining() + rack.get_tiles().length()

	assert_eq(total_after, total_before, "Total tiles should be conserved")


func test_exchange_flow_complete():
	var bag = autofree(TileBag.new())

	# Start game
	var human_hand = bag.draw_balanced_tiles(7)
	var ai_hand = bag.draw_balanced_tiles(7)
	var human_rack = autofree(TileRack.new(human_hand))
	var ai_rack = autofree(TileRack.new(ai_hand))

	# Human decides to exchange 3 tiles
	var exchange_count = 3
	var tiles_to_exchange = human_hand.substr(0, exchange_count)

	# Remove tiles from rack
	for c in tiles_to_exchange:
		human_rack.remove_letter(c)

	assert_eq(
		human_rack.get_tiles().length(),
		7 - exchange_count,
		"Rack should have fewer tiles after removing exchange tiles"
	)

	# Get new tiles
	var new_tiles = bag.exchange(tiles_to_exchange)
	assert_eq(new_tiles.length(), exchange_count, "Should get same number of new tiles")

	# Add back to rack
	human_rack.add_tiles(new_tiles)
	assert_eq(human_rack.get_tiles().length(), 7, "Rack should have 7 tiles again")


func test_exchange_maintains_tile_count():
	var bag = autofree(TileBag.new())

	# Draw initial hands and track total
	var hand1 = bag.draw_balanced_tiles(7)
	var hand2 = bag.draw_balanced_tiles(7)

	var after_draw_total = bag.remaining() + hand1.length() + hand2.length()
	assert_eq(
		after_draw_total,
		bag.remaining() + hand1.length() + hand2.length(),
		"Sanity check should always pass"
	)

	# Create rack with actual tiles from hand1 and exchange some
	var rack = autofree(TileRack.new(hand1))
	var tiles_to_exchange = hand1.substr(0, 3)
	for c in tiles_to_exchange:
		rack.remove_letter(c)

	var exchange_result = bag.exchange(tiles_to_exchange)
	rack.add_tiles(exchange_result)

	# Total should be conserved: bag + rack + hand2 = original total
	var after_exchange_total = bag.remaining() + rack.get_tiles().length() + hand2.length()
	assert_eq(after_exchange_total, after_draw_total, "Tile count should remain after exchange")


func _count_vowels(tiles: String) -> int:
	var vowels := "AEIOUÄÖÜ"
	var count := 0
	for c in tiles:
		if vowels.contains(c):
			count += 1
	return count


func _count_consonants(tiles: String) -> int:
	var vowels := "AEIOUÄÖÜ"
	var count := 0
	for c in tiles:
		if not vowels.contains(c) and c != "_":
			count += 1
	return count
