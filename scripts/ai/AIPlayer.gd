class_name AIPlayer
extends RefCounted

const Board = preload("res://scripts/game/Board.gd")
const MoveGenerator = preload("res://scripts/ai/MoveGenerator.gd")
const Trie = preload("res://scripts/game/Trie.gd")

enum Difficulty {
	EASY,
	MEDIUM,
	HARD,
}

signal move_chosen(move_data: Dictionary)
signal thinking_started
signal thinking_finished

var difficulty: int = Difficulty.HARD
var move_generator: MoveGenerator
var trie: Trie

var _thinking := false


func _init(diff: int = Difficulty.HARD, mg = null, t = null):
	difficulty = diff
	move_generator = mg if mg else MoveGenerator.new()
	trie = t


func set_difficulty(d: int) -> void:
	difficulty = d


func get_difficulty() -> int:
	return difficulty


func get_difficulty_name() -> String:
	match difficulty:
		Difficulty.EASY:
			return "Easy"
		Difficulty.MEDIUM:
			return "Medium"
		Difficulty.HARD:
			return "Hard"
	return "Unknown"


func is_thinking() -> bool:
	return _thinking


func choose_move(board, rack: String) -> Dictionary:
	thinking_started.emit()
	_thinking = true

	if trie == null:
		push_warning("AIPlayer: trie is null, cannot generate moves")
		_thinking = false
		thinking_finished.emit()
		return _make_pass_move()

	var moves = move_generator.generate_moves(board, rack, trie)

	if moves.is_empty():
		_thinking = false
		thinking_finished.emit()
		return _make_pass_move()

	var chosen = _select_move(moves)

	_thinking = false
	thinking_finished.emit()
	move_chosen.emit(chosen)
	return chosen


func _select_move(moves: Array) -> Dictionary:
	var move_count = moves.size()

	match difficulty:
		Difficulty.EASY:
			return _select_easy(moves, move_count)
		Difficulty.MEDIUM:
			return _select_medium(moves, move_count)
		Difficulty.HARD:
			return _select_hard(moves)
		_:
			return _select_hard(moves)


func _select_hard(moves: Array) -> Dictionary:
	var scored = _evaluate_moves(moves)
	scored.sort_custom(func(a, b): return a.eval_score > b.eval_score)
	if scored.is_empty():
		return _make_pass_move()
	if randf() < 0.05:
		var top_half = maxi(1, ceil(scored.size() * 0.5))
		return scored[randi() % top_half]
	return scored[0]


func _select_medium(moves: Array, count: int) -> Dictionary:
	var scored = _evaluate_moves(moves)
	scored.sort_custom(func(a, b): return a.eval_score > b.eval_score)

	var top_percent = maxi(1, ceil(count * 0.3))
	var top_moves = scored.slice(0, top_percent)
	var chosen = top_moves[randi() % top_moves.size()]
	return chosen


func _select_easy(moves: Array, count: int) -> Dictionary:
	if count > 2 and randf() < 0.1:
		return _make_pass_move()

	var scored = _evaluate_moves(moves)
	scored.sort_custom(func(a, b): return a.eval_score > b.eval_score)

	var bottom_percent = maxi(1, ceil(count * 0.4))
	var bottom_moves = scored.slice(scored.size() - bottom_percent, scored.size())

	if bottom_moves.is_empty():
		bottom_moves = scored

	var chosen = bottom_moves[randi() % bottom_moves.size()]
	return chosen


func _evaluate_moves(moves: Array) -> Array:
	var scored: Array = []

	for m in moves:
		var eval_score := 0.0
		var score_weight := 1.0
		var leave_weight := 0.3
		var bonus_penalty := 0.15

		eval_score += m.score * score_weight

		eval_score += _evaluate_rack_leave(m) * leave_weight

		eval_score += _evaluate_defensive(m) * bonus_penalty

		(
			scored
			. append(
				{
					"word": m.word,
					"row": m.row,
					"col": m.col,
					"horizontal": m.horizontal,
					"score": m.score,
					"tiles_placed": m.tiles_placed,
					"rack_leave": m.rack_leave,
					"eval_score": eval_score,
				}
			)
		)

	return scored


func _evaluate_rack_leave(move) -> float:
	var leave = move.rack_leave
	var score := 0.0

	if leave.length() == 0:
		return 5.0

	for c in leave:
		match c:
			"E", "R", "S", "N", "T", "I", "A", "U":
				score += 1.0
			"Q", "X", "Y", "J", "V":
				score -= 1.5
			"Ä", "Ö", "Ü", "C", "P", "F", "H", "K", "M", "W", "Z", "B", "D", "G", "L", "O":
				score -= 0.5

	var vowel_count := 0
	var consonant_count := 0
	for c in leave:
		if c in "AEIOUÄÖÜ":
			vowel_count += 1
		else:
			consonant_count += 1

	if vowel_count >= 1 and consonant_count >= 1:
		score += 1.0
	elif vowel_count == 0 and leave.length() > 0:
		score -= 1.0
	elif consonant_count == 0 and leave.length() > 0:
		score -= 0.5

	return score


func _evaluate_defensive(move) -> float:
	var penalty := 0.0

	for tp in move.tiles_placed:
		var bonuses = [
			Vector2i(tp.x - 1, tp.y - 1),
			Vector2i(tp.x - 1, tp.y + 1),
			Vector2i(tp.x + 1, tp.y - 1),
			Vector2i(tp.x + 1, tp.y + 1),
		]

		var idx = _word_index(move, tp)
		var letter = move.word[idx] if idx >= 0 and idx < move.word.length() else ""

		for b in bonuses:
			var bonus_type = _get_bonus_if_on_board(b.x, b.y)
			if bonus_type == Board.BONUS_TW:
				if not _is_vowel(letter):
					penalty -= 2.0
				else:
					penalty -= 4.0
			elif bonus_type == Board.BONUS_DW:
				penalty -= 1.0

	var high_score_ratio = float(move.score) / 50.0
	if high_score_ratio > 0.5:
		penalty += high_score_ratio * 5.0

	return penalty


## Converts a board position to its index within move.word.
## Mirrors the convention used when applying moves in Game.gd.
func _word_index(move, pos: Vector2i) -> int:
	return (pos.y - move.col) if move.horizontal else (pos.x - move.row)


func _is_vowel(c: String) -> bool:
	return c in "AEIOUÄÖÜ"


func _get_bonus_if_on_board(row: int, col: int) -> int:
	return Board.get_bonus_at(row, col)


func _make_pass_move() -> Dictionary:
	return {
		"word": "",
		"row": -1,
		"col": -1,
		"horizontal": true,
		"score": 0,
		"tiles_placed": [],
		"rack_leave": "",
		"eval_score": 0.0,
		"passed": true,
	}
