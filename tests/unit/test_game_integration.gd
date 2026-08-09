extends GutTest

const Board = preload("res://scripts/game/Board.gd")
const Trie = preload("res://scripts/game/Trie.gd")
const MoveGenerator = preload("res://scripts/ai/MoveGenerator.gd")
const AIPlayer = preload("res://scripts/ai/AIPlayer.gd")
const Scoring = preload("res://scripts/game/Scoring.gd")
const Tiles = preload("res://scripts/game/Tiles.gd")


func _make_minimal_trie() -> Trie:
	var t = autofree(Trie.new())
	for w in ["AT", "CAT"]:
		t.insert(w)
	return t


func test_full_game_ai_plays_two_words() -> void:
	var trie = _make_minimal_trie()
	var board = autofree(Board.new())
	var mg = autofree(MoveGenerator.new())
	var ai = autofree(AIPlayer.new(AIPlayer.Difficulty.HARD, mg, trie))

	# Move 1: AI plays "AT" from center (7,7) as first word
	var move1 = ai.choose_move(board, "AT")
	assert_false(move1.get("passed", false), "AI should not pass with AT rack")
	assert_eq(move1.word, "AT", "First word should be AT")
	assert_eq(move1.row, 7, "First word row should be center (7)")
	assert_eq(move1.col, 7, "First word col should be center (7)")
	assert_true(move1.horizontal, "First word should be horizontal")
	assert_eq(move1.score, 2, "A(1)+T(1) with no bonuses = 2")

	# Place "AT" on the board
	for tp in move1.tiles_placed:
		var idx = move1.tiles_placed.find(tp)
		board.place_tile(tp.x, tp.y, move1.word[idx])

	assert_eq(board.get_tile(7, 7), "A")
	assert_eq(board.get_tile(7, 8), "T")

	# Move 2: AI plays "CAT" by placing C left of AT
	var move2 = ai.choose_move(board, "C")
	assert_false(move2.get("passed", false), "AI should not pass with C rack")
	assert_eq(move2.word, "CAT", "Second word should be CAT extending AT")

	var found_c_pos = false
	for tp in move2.tiles_placed:
		if tp.x == 7 and tp.y == 6:
			found_c_pos = true
			break
	assert_true(found_c_pos, "C should be placed at (7,6) left of A")

	var expected_cat_score = Scoring.calculate(board, "CAT", 7, 6, true, move2.tiles_placed)
	assert_eq(move2.score, expected_cat_score, "Score should match Scoring.calculate")

	# Place "C" on the board
	for tp in move2.tiles_placed:
		var idx = move2.tiles_placed.find(tp)
		board.place_tile(tp.x, tp.y, move2.word[idx])

	# Verify final board state
	assert_eq(board.get_tile(7, 6), "C")
	assert_eq(board.get_tile(7, 7), "A")
	assert_eq(board.get_tile(7, 8), "T")

	# Verify all words on the board are valid
	var all_words = board.get_all_words(trie)
	for w in all_words:
		assert_true(trie.search(w.word), "Every word on board must be valid: " + w.word)

	# Total combined score
	var total = move1.score + move2.score
	assert_eq(total, 8, "CAT via AT extension: A(1)+T(1)=2 then C(4)+A(1)+T(1)=6, total=8")

	# Move 3: With empty rack, AI has no moves and must pass
	var move3 = ai.choose_move(board, "")
	assert_true(move3.get("passed", false), "AI must pass with empty rack")
	assert_eq(move3.score, 0, "Pass move should have 0 score")


func test_full_game_produces_reproducible_scores() -> void:
	var trie = _make_minimal_trie()
	var board = autofree(Board.new())
	var mg = autofree(MoveGenerator.new())
	var ai = autofree(AIPlayer.new(AIPlayer.Difficulty.HARD, mg, trie))

	var move1 = ai.choose_move(board, "AT")
	assert_eq(move1.word, "AT", "First word always AT")
	assert_eq(move1.score, 2)

	for tp in move1.tiles_placed:
		var idx = move1.tiles_placed.find(tp)
		board.place_tile(tp.x, tp.y, move1.word[idx])

	var move2 = ai.choose_move(board, "C")
	assert_eq(move2.word, "CAT", "Second word always CAT")

	for tp in move2.tiles_placed:
		var idx = move2.tiles_placed.find(tp)
		board.place_tile(tp.x, tp.y, move2.word[idx])

	# Run again to verify reproducibility
	var board2 = autofree(Board.new())
	var ai2 = autofree(AIPlayer.new(AIPlayer.Difficulty.HARD, mg, trie))

	var m1 = ai2.choose_move(board2, "AT")
	for tp in m1.tiles_placed:
		board2.place_tile(tp.x, tp.y, m1.word[m1.tiles_placed.find(tp)])

	var m2 = ai2.choose_move(board2, "C")
	for tp in m2.tiles_placed:
		board2.place_tile(tp.x, tp.y, m2.word[m2.tiles_placed.find(tp)])

	assert_eq(m1.score, move1.score, "First move score should be reproducible")
	assert_eq(m2.score, move2.score, "Second move score should be reproducible")
	assert_eq(m2.word, move2.word, "Second word should be reproducible")

	# Verify board states match
	for r in range(Board.SIZE):
		for c in range(Board.SIZE):
			assert_eq(
				board2.get_tile(r, c),
				board.get_tile(r, c),
				"Board state should match at (%d,%d)" % [r, c]
			)


func test_game_ends_via_consecutive_passes() -> void:
	var trie = autofree(Trie.new())
	var board = autofree(Board.new())
	var mg = autofree(MoveGenerator.new())
	var ai = autofree(AIPlayer.new(AIPlayer.Difficulty.EASY, mg, trie))

	# Empty trie means no valid words can be formed
	# Every AI turn results in a pass
	var consecutive_passes := 0

	# Simulate alternating turns; each AI player passes
	var rack = "ABCDEFG"
	for turn in range(10):
		var move = ai.choose_move(board, rack)
		if move.get("passed", false):
			consecutive_passes += 1
		else:
			consecutive_passes = 0
			for tp in move.tiles_placed:
				board.place_tile(tp.x, tp.y, move.word[move.tiles_placed.find(tp)])

		# Check game-over trigger (6 consecutive passes = 3 per side in real game)
		if consecutive_passes >= 6:
			break

	assert_true(consecutive_passes >= 6, "Game should end after 6 consecutive passes")
	assert_true(board.is_first_move(), "Board should be empty (all passes)")
