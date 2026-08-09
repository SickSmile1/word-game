extends GutTest

const TileBag = preload("res://scripts/game/TileBag.gd")


func _count_vowels_consonants(tiles: String) -> Dictionary:
	var vowels := "AEIOUÄÖÜ"
	var vowel_count := 0
	var consonant_count := 0

	for c in tiles:
		if vowels.contains(c):
			vowel_count += 1
		elif c != "_":
			consonant_count += 1

	return {"vowels": vowel_count, "consonants": consonant_count}


func test_balanced_draw_returns_7_tiles():
	var bag = autofree(TileBag.new())
	var tiles = bag.draw_balanced_tiles(7)
	assert_eq(tiles.length(), 7, "draw_balanced_tiles should return 7 tiles")


func test_balanced_draw_has_2_vowels():
	var bag = autofree(TileBag.new())
	var tiles = bag.draw_balanced_tiles(7)
	var counts = _count_vowels_consonants(tiles)
	assert_gte(counts.vowels, 2, "Balanced draw should have at least 2 vowels")


func test_balanced_draw_has_2_consonants():
	var bag = autofree(TileBag.new())
	var tiles = bag.draw_balanced_tiles(7)
	var counts = _count_vowels_consonants(tiles)
	assert_gte(counts.consonants, 2, "Balanced draw should have at least 2 consonants")


func test_multiple_balanced_draws_maintain_constraint():
	var bag = autofree(TileBag.new())

	# Draw first hand
	var hand1 = bag.draw_balanced_tiles(7)
	var counts1 = _count_vowels_consonants(hand1)
	assert_gte(counts1.vowels, 2, "First draw should have at least 2 vowels")
	assert_gte(counts1.consonants, 2, "First draw should have at least 2 consonants")

	# Draw second hand
	var hand2 = bag.draw_balanced_tiles(7)
	var counts2 = _count_vowels_consonants(hand2)
	assert_gte(counts2.vowels, 2, "Second draw should have at least 2 vowels")
	assert_gte(counts2.consonants, 2, "Second draw should have at least 2 consonants")


func test_balanced_draw_no_duplicates_in_two_hands():
	var bag = autofree(TileBag.new())
	var hand1 = bag.draw_balanced_tiles(7)
	var hand2 = bag.draw_balanced_tiles(7)

	# Verify they're different hands (not the same tiles)
	assert_ne(hand1 + hand2, "", "Both hands should have tiles")
	assert_ne(hand1, hand2, "Two consecutive balanced draws should not be identical")
