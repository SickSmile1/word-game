extends GutTest

const Board = preload("res://scripts/game/Board.gd")
const Trie = preload("res://scripts/game/Trie.gd")
const MoveGenerator = preload("res://scripts/ai/MoveGenerator.gd")
const Scoring = preload("res://scripts/game/Scoring.gd")

var _move_gen


func before_each() -> void:
	_move_gen = autofree(MoveGenerator.new())


func _make_trie() -> Trie:
	var t = autofree(Trie.new())
	var words = [
		"CAT",
		"CATS",
		"SCAT",
		"CATER",
		"CAN",
		"CANE",
		"CART",
		"POND",
		"PONDER",
		"PONDS",
		"DOG",
		"DOGS",
		"AT",
		"DO",
		"ON",
		"NO",
		"TO",
		"SO",
		"PA",
		"PO",
		"OP",
		"AN",
		"AD",
		"AE",
		"ED",
		"EN",
		"ES",
		"ET",
		"NE",
		"OD",
		"OE",
		"OS",
		"OW",
		"PE",
		"RE",
		"TA",
		"TE",
		"TI",
		"CAR",
		"CARD",
		"CARE",
		"CARN",
		"CART",
		"SPA",
		"SPAN",
		"SPAND",
		"SPANE",
		"SPANK",
		"SPANKS",
		"SON",
		"SONS",
		"SONDE",
		"SONDES",
		"ONE",
		"ONES",
		"PEN",
		"PENS",
		"PEND",
		"PENDS",
		"END",
		"ENDS",
		"SEND",
		"SENDS",
		"AND",
		"SAND",
		"SANDS",
		"TAP",
		"TAPS",
		"TAN",
		"TANS",
		"TAD",
		"CAP",
		"CAPS",
		"NAP",
		"NAPS",
		"SAP",
		"SAPS",
		"DAP",
		"PAN",
		"PANS",
		"PANE",
		"PANES",
		"NODE",
		"NODES",
		"NOTE",
		"NOTES",
		"DOTE",
		"DOTES",
		"CODE",
		"TOTE",
		"CONE",
		"TON",
		"TONS",
		"TONE",
		"TONES",
		"CANT",
		"CANTS",
		"SCAN",
		"SCANS",
		"SCANT",
		"SCONE",
		"SCONES",
		"ASCOT",
	]
	for w in words:
		t.insert(w)
	return t


func test_generate_moves_returns_array() -> void:
	var board = autofree(Board.new())
	var trie = _make_trie()
	board.place_tile(7, 7, "A")

	var moves = _move_gen.generate_moves(board, "CAT", trie)

	assert_true(moves is Array)


func test_first_move_generates_words() -> void:
	var board = autofree(Board.new())
	var trie = autofree(Trie.new())
	trie.insert("CAT")

	var moves = _move_gen.generate_moves(board, "CAT", trie)

	assert_gt(moves.size(), 0)


func test_first_move_finds_center_word() -> void:
	var board = autofree(Board.new())
	var trie = autofree(Trie.new())
	trie.insert("CAT")

	var moves = _move_gen.generate_moves(board, "CAT", trie)

	var found = false
	for m in moves:
		if m.word == "CAT" and m.horizontal and m.col == 7 and m.row == 7:
			found = true
	assert_true(found)


func test_horizontal_extension_finds_cats() -> void:
	var board = autofree(Board.new())
	board.place_tile(7, 7, "A")
	board.place_tile(7, 8, "T")
	var trie = _make_trie()

	var moves = _move_gen.generate_moves(board, "SXCDEN", trie)

	var found = false
	for m in moves:
		if m.word == "CATS" and m.horizontal:
			found = true
			break
	assert_true(found)


func test_no_invalid_words_generated() -> void:
	var board = autofree(Board.new())
	board.place_tile(7, 7, "A")
	var trie = _make_trie()

	var moves = _move_gen.generate_moves(board, "SXCDEN", trie)

	for m in moves:
		assert_true(trie.search(m.word), "Every generated word must be valid: " + m.word)


func test_generated_moves_have_scores() -> void:
	var board = autofree(Board.new())
	var trie = autofree(Trie.new())
	trie.insert("AT")

	var moves = _move_gen.generate_moves(board, "AT", trie)

	for m in moves:
		assert_gt(m.score, 0)


func test_generated_moves_have_correct_orientation() -> void:
	var board = autofree(Board.new())
	var trie = _make_trie()
	board.place_tile(7, 7, "A")
	board.place_tile(7, 8, "T")

	var moves = _move_gen.generate_moves(board, "SXCDEN", trie)

	for m in moves:
		if m.word == "CATS":
			assert_true(m.horizontal, "CATS should be horizontal")
		if m.word == "SCAT":
			assert_true(m.horizontal, "SCAT should be horizontal")
