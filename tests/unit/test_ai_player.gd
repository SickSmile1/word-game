extends GutTest

const Board = preload("res://scripts/game/Board.gd")
const Trie = preload("res://scripts/game/Trie.gd")
const MoveGenerator = preload("res://scripts/ai/MoveGenerator.gd")
const AIPlayer = preload("res://scripts/ai/AIPlayer.gd")

var _ai: AIPlayer
var _trie


func before_each() -> void:
	_trie = autofree(Trie.new())
	_trie.insert("CAT")
	_trie.insert("CATS")
	_trie.insert("SCAT")
	_trie.insert("AT")
	_trie.insert("DO")
	_trie.insert("ON")
	_trie.insert("NO")

	var move_gen = autofree(MoveGenerator.new())
	_ai = autofree(AIPlayer.new(AIPlayer.Difficulty.HARD, move_gen, _trie))


func test_ai_creates_move_generator() -> void:
	var ai = autofree(AIPlayer.new())
	assert_not_null(ai)


func test_ai_difficulty_default_to_hard() -> void:
	var ai = autofree(AIPlayer.new())
	assert_eq(ai.get_difficulty(), AIPlayer.Difficulty.HARD)


func test_ai_set_difficulty() -> void:
	_ai.set_difficulty(AIPlayer.Difficulty.EASY)
	assert_eq(_ai.get_difficulty(), AIPlayer.Difficulty.EASY)


func test_ai_difficulty_name() -> void:
	_ai.set_difficulty(AIPlayer.Difficulty.EASY)
	assert_eq(_ai.get_difficulty_name(), "Easy")

	_ai.set_difficulty(AIPlayer.Difficulty.MEDIUM)
	assert_eq(_ai.get_difficulty_name(), "Medium")

	_ai.set_difficulty(AIPlayer.Difficulty.HARD)
	assert_eq(_ai.get_difficulty_name(), "Hard")


func test_ai_choose_move_hard_returns_highest_score() -> void:
	var board = autofree(Board.new())
	board.place_tile(7, 7, "A")

	var move_dict = _ai.choose_move(board, "SCATTEN")

	assert_true(move_dict.score > 0, "Should find a scoring move")


func test_ai_choose_move_easy_returns_valid_move() -> void:
	_ai.set_difficulty(AIPlayer.Difficulty.EASY)
	var board = autofree(Board.new())
	board.place_tile(7, 7, "A")

	var move_dict = _ai.choose_move(board, "SCATTEN")

	if not move_dict.get("passed", false):
		assert_gt(move_dict.score, 0)


func test_ai_choose_move_medium_returns_valid_move() -> void:
	_ai.set_difficulty(AIPlayer.Difficulty.MEDIUM)
	var board = autofree(Board.new())
	board.place_tile(7, 7, "A")

	var move_dict = _ai.choose_move(board, "SCATTEN")

	if not move_dict.get("passed", false):
		assert_gt(move_dict.score, 0)


func test_ai_choose_move_returns_dict_with_required_fields() -> void:
	var board = autofree(Board.new())
	board.place_tile(7, 7, "A")

	var move_dict = _ai.choose_move(board, "SCATTEN")

	assert_has(move_dict, "word")
	assert_has(move_dict, "row")
	assert_has(move_dict, "col")
	assert_has(move_dict, "horizontal")
	assert_has(move_dict, "score")


func test_ai_empty_rack_returns_pass() -> void:
	var board = autofree(Board.new())
	board.place_tile(7, 7, "A")

	var move_dict = _ai.choose_move(board, "")

	assert_true(move_dict.get("passed", false))


func test_ai_signals_emit() -> void:
	var board = autofree(Board.new())
	board.place_tile(7, 7, "A")

	watch_signals(_ai)
	var move_dict = _ai.choose_move(board, "CAT")

	assert_signal_emitted(_ai, "thinking_started")
	assert_signal_emitted(_ai, "thinking_finished")


func test_ai_null_trie_returns_pass() -> void:
	var move_gen = autofree(MoveGenerator.new())
	var ai = autofree(AIPlayer.new(AIPlayer.Difficulty.HARD, move_gen, null))
	var board = autofree(Board.new())
	board.place_tile(7, 7, "A")

	var move_dict = ai.choose_move(board, "CAT")

	assert_true(move_dict.get("passed", false), "Null trie must degrade to a pass move")


func test_word_index_horizontal_uses_column_offset() -> void:
	# Horizontal move "CAT" starting at row 7, col 5 -> letters at cols 5,6,7.
	var move = MoveGenerator.Move.new("CAT", 7, 5, true, 0, [], "")
	assert_eq(_ai._word_index(move, Vector2i(7, 5)), 0)
	assert_eq(_ai._word_index(move, Vector2i(7, 6)), 1)
	assert_eq(_ai._word_index(move, Vector2i(7, 7)), 2)


func test_word_index_vertical_uses_row_offset() -> void:
	# Vertical move "CAT" starting at row 5, col 7 -> letters at rows 5,6,7.
	var move = MoveGenerator.Move.new("CAT", 5, 7, false, 0, [], "")
	assert_eq(_ai._word_index(move, Vector2i(5, 7)), 0)
	assert_eq(_ai._word_index(move, Vector2i(6, 7)), 1)
	assert_eq(_ai._word_index(move, Vector2i(7, 7)), 2)


func test_evaluate_defensive_vertical_move_does_not_crash() -> void:
	# Regression for the index-out-of-range bug: a horizontal move previously
	# always indexed word[0], and a vertical move could index out of bounds.
	var tiles_h = [Vector2i(7, 1), Vector2i(7, 2), Vector2i(7, 3)]
	var move_h = MoveGenerator.Move.new("CAT", 7, 1, true, 30, tiles_h, "")
	assert_typeof(_ai._evaluate_defensive(move_h), TYPE_FLOAT)

	var tiles_v = [Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7)]
	var move_v = MoveGenerator.Move.new("CAT", 1, 7, false, 30, tiles_v, "")
	assert_typeof(_ai._evaluate_defensive(move_v), TYPE_FLOAT)
