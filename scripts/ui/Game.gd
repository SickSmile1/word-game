extends Control

enum GameState { DIFFICULTY_SELECT, HUMAN_TURN, AI_THINKING, WAITING, GAME_OVER }

const Board = preload("res://scripts/game/Board.gd")
const GameOnline = preload("res://scripts/ui/GameOnline.gd")
const GameSession = preload("res://scripts/game/GameSession.gd")
const Tiles = preload("res://scripts/game/Tiles.gd")
const TileRack = preload("res://scripts/game/TileRack.gd")
const TileBag = preload("res://scripts/game/TileBag.gd")
const Scoring = preload("res://scripts/game/Scoring.gd")
const MoveGenerator = preload("res://scripts/ai/MoveGenerator.gd")
const AIPlayer = preload("res://scripts/ai/AIPlayer.gd")

const BUTTON_HEIGHT := 58.0

var _state: int = GameState.DIFFICULTY_SELECT
var _difficulty: int = AIPlayer.Difficulty.HARD
var _board: Board
var _bag: TileBag
var _human_rack: TileRack
var _ai_rack: TileRack
var _human_score: int = 0
var _ai_score: int = 0
var _consecutive_passes: int = 0
var _ai_player: AIPlayer
var _selected_rack_index: int = -1
var _placed_rack_indices: Array[int] = []
var _pending_placements: Array[Dictionary] = []
var _exchange_mode: bool = false
var _save_slot: int = -1
var _preview_valid_cache: bool = false
var _preview_dirty: bool = true
var _online_mode: bool = false
var _my_turn: bool = false
var _bag_count: int = 0
var _online: GameOnline

@onready var difficulty_panel: Panel = %DifficultyPanel
@onready var easy_button: Button = %EasyButton
@onready var medium_button: Button = %MediumButton
@onready var hard_button: Button = %HardButton
@onready var game_ui: Control = %GameUI
@onready var top_hud: HBoxContainer = $GameUI/TopHUD
@onready var action_buttons: HBoxContainer = $GameUI/ActionButtons
@onready var rack_container: CenterContainer = $GameUI/RackContainer
@onready var board_container: Control = %BoardContainer
@onready var board_display = %BoardDisplay
@onready var rack_display = %RackDisplay
@onready var player_score_label: Label = %PlayerScore
@onready var ai_score_label: Label = %AIScore
@onready var status_label: Label = %StatusLabel
@onready var submit_button: Button = %SubmitButton
@onready var pass_button: Button = %PassButton
@onready var exchange_button: Button = %ExchangeButton
@onready var menu_button: Button = %MenuButton
@onready var game_overlay = %GameOverOverlay
@onready var theme_button: Button = %ThemeButton
@onready var background: ColorRect = $Background


func _ready():
	_setup_signals()
	_apply_background(Settings.dark_mode)
	_update_theme_button(Settings.dark_mode)
	_style_scene_theme(Settings.dark_mode)
	get_viewport().size_changed.connect(_relayout)
	_relayout()

	if Net.active:
		_online_mode = true
		difficulty_panel.visible = false
		game_ui.visible = true
		game_overlay.visible = false
		_online = GameOnline.new(self)
		_online.setup()
		return

	if SaveManager.pending_load_slot >= 0:
		var slot = SaveManager.pending_load_slot
		SaveManager.pending_load_slot = -1
		var data = SaveManager.load_data(slot)
		if not data.is_empty():
			await _apply_save_data(slot, data)
			return

	difficulty_panel.visible = true
	game_ui.visible = false
	game_overlay.visible = false


func _setup_signals():
	easy_button.pressed.connect(func(): _on_difficulty_selected(AIPlayer.Difficulty.EASY))
	medium_button.pressed.connect(func(): _on_difficulty_selected(AIPlayer.Difficulty.MEDIUM))
	hard_button.pressed.connect(func(): _on_difficulty_selected(AIPlayer.Difficulty.HARD))
	board_display.cell_clicked.connect(_on_board_cell_clicked)
	board_display.tile_drag_dropped.connect(_on_board_cell_clicked)
	rack_display.tile_selected.connect(_on_rack_tile_selected)
	rack_display.tile_deselected.connect(_on_rack_tile_deselected)
	rack_display.placed_tile_clicked.connect(_on_placed_tile_clicked)
	submit_button.pressed.connect(_on_submit)
	pass_button.pressed.connect(_on_pass)
	exchange_button.pressed.connect(_on_exchange)
	menu_button.pressed.connect(_on_main_menu)
	theme_button.pressed.connect(_on_theme_toggle)
	game_overlay.play_again_pressed.connect(_on_play_again)
	game_overlay.main_menu_pressed.connect(_on_main_menu)
	Settings.theme_changed.connect(_on_theme_changed)


func _resize_board():
	# Kept for callers that await a layout pass; defers to _relayout.
	await get_tree().process_frame
	_relayout()


# Lays out the in-game HUD, board, action buttons and rack for the current
# viewport aspect ratio. Supports both portrait and landscape so the game can
# be played rotated either way.
func _relayout():
	if not is_inside_tree():
		return
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 0 or vp.y <= 0:
		return
	if vp.x > vp.y:
		_layout_landscape(vp)
	else:
		_layout_portrait(vp)


func _set_rect(node: Control, x: float, y: float, w: float, h: float):
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = x
	node.offset_top = y
	node.offset_right = x + w
	node.offset_bottom = y + h


func _set_board(x: float, y: float, s: float):
	_set_rect(board_container, x, y, s, s)
	board_display.position = Vector2.ZERO
	board_display.custom_minimum_size = Vector2(s, s)
	board_display.size = Vector2(s, s)


func _layout_portrait(vp: Vector2):
	var m := 6.0
	var hud_h := 44.0
	var status_h := 30.0
	var rack_h := 80.0
	var btn_h: float = BUTTON_HEIGHT
	var gap := 3.0

	var avail_w := vp.x - 2.0 * m
	var fixed_h := hud_h + status_h + btn_h + rack_h + 5.0 * gap
	var board_size: float = min(avail_w, vp.y - fixed_h)
	var y: float = max(gap, (vp.y - fixed_h - board_size) / 2.0)

	_set_rect(top_hud, m, y, avail_w, hud_h)
	y += hud_h + gap

	_set_rect(status_label, m, y, avail_w, status_h)
	y += status_h + gap

	_set_board((vp.x - board_size) / 2.0, y, board_size)
	y += board_size + gap

	_set_rect(action_buttons, m, y, avail_w, btn_h)
	y += btn_h + gap

	_set_rect(rack_container, m, y, avail_w, rack_h)


func _layout_landscape(vp: Vector2):
	var m := 6.0
	var min_panel := 260.0
	var board_size: float = vp.y - 2.0 * m
	board_size = min(board_size, vp.x - min_panel - 3.0 * m)

	var bx := m
	var by := (vp.y - board_size) / 2.0
	_set_board(bx, by, board_size)

	var px := bx + board_size + m
	var pw := vp.x - px - m
	var hud_h := 44.0
	var status_h := 30.0
	var rack_h := 80.0
	var btn_h: float = BUTTON_HEIGHT
	var gap := 3.0

	var panel_h := hud_h + status_h + btn_h + rack_h + 4.0 * gap
	var y: float = max(m, (vp.y - panel_h) / 2.0)

	_set_rect(top_hud, px, y, pw, hud_h)
	y += hud_h + gap

	_set_rect(status_label, px, y, pw, status_h)
	y += status_h + gap

	_set_rect(action_buttons, px, y, pw, btn_h)
	y += btn_h + gap

	_set_rect(rack_container, px, y, pw, rack_h)


func _is_word_valid(word: String) -> bool:
	return WordDict.is_valid_word(word)


func _on_difficulty_selected(diff: int):
	_difficulty = diff
	difficulty_panel.visible = false
	game_ui.visible = true
	await _resize_board()
	if not WordDict.is_ready:
		_set_status("Loading dictionary...")
		await WordDict.dictionary_ready
	_start_game()
	_save_slot = _assign_save_slot()
	_auto_save()


func _start_game():
	_board = Board.new()
	_bag = TileBag.new()
	_human_rack = TileRack.new(_bag.draw_balanced_tiles(7))
	_ai_rack = TileRack.new(_bag.draw_balanced_tiles(7))
	_human_score = 0
	_ai_score = 0
	_consecutive_passes = 0
	_reset_turn_state()

	if not WordDict.is_ready or WordDict.trie == null:
		push_error("Game: word dictionary is not ready; AI and word validation will not work")
		_set_status("Dictionary failed to load — cannot start game")
		return

	var mg = MoveGenerator.new()
	_ai_player = AIPlayer.new(_difficulty, mg, WordDict.trie)

	_update_display()
	_start_human_turn()


func _start_human_turn():
	_state = GameState.HUMAN_TURN
	_my_turn = true
	_reset_turn_state()
	rack_display.set_exchange_mode(false)
	rack_display.clear_selection()
	_set_status("Your turn")
	_update_display()


func _reset_turn_state():
	_pending_placements = []
	_placed_rack_indices = []
	_selected_rack_index = -1
	_exchange_mode = false
	_preview_dirty = true


func _start_ai_turn():
	_state = GameState.AI_THINKING
	_set_status("AI thinking...")
	rack_display.clear_selection()
	submit_button.disabled = true
	pass_button.disabled = true
	exchange_button.disabled = true

	await get_tree().create_timer(0.3).timeout

	var move = _ai_player.choose_move(_board, _ai_rack.get_tiles())

	if move.get("passed", false):
		_consecutive_passes += 1
		_set_status("AI passed")
		await get_tree().create_timer(0.8).timeout
	else:
		_consecutive_passes = 0
		var word = move.word
		var row = move.row
		var col = move.col
		var horizontal = move.horizontal
		var tiles_placed = move.tiles_placed
		var score = move.score

		for tp in tiles_placed:
			var idx = (tp.y - col) if horizontal else (tp.x - row)
			if idx >= 0 and idx < word.length():
				_board.place_tile(tp.x, tp.y, word[idx])

		for tp in tiles_placed:
			var idx = (tp.y - col) if horizontal else (tp.x - row)
			if idx >= 0 and idx < word.length():
				_ai_rack.remove_letter(word[idx])

		_ai_score += score
		_set_status('AI played "%s" for %d' % [word, score])
		_draw_ai_tiles()

		await get_tree().create_timer(1.2).timeout

	_update_display()
	_auto_save()

	if await _check_end_game():
		return

	_start_human_turn()


func _draw_human_tiles():
	var needed = 7 - _human_rack.size()
	if needed > 0:
		var drawn = _bag.draw_tiles(needed)
		_human_rack.add_tiles(drawn)


func _draw_ai_tiles():
	var needed = 7 - _ai_rack.size()
	if needed > 0:
		var drawn = _bag.draw_tiles(needed)
		_ai_rack.add_tiles(drawn)


func _apply_human_move(result: Dictionary):
	var word = result.word
	var row = result.row
	var col = result.col
	var horizontal = result.horizontal
	var score = result.score

	for pp in _pending_placements:
		_board.place_tile(pp.pos.x, pp.pos.y, pp.letter)
		_human_rack.remove_letter(pp.letter)

	_human_score += score
	_pending_placements = []
	_placed_rack_indices = []
	_selected_rack_index = -1
	_consecutive_passes = 0
	_set_status('"%s" scores %d!' % [word, score])
	_draw_human_tiles()
	_update_display()
	_auto_save()

	await get_tree().create_timer(0.8).timeout

	if await _check_end_game():
		return

	_start_ai_turn()


func _check_end_game() -> bool:
	if _consecutive_passes >= 6:
		_end_game("Both players passed 3 times! Game over.")
		return true

	var human_empty = _human_rack.is_empty()
	var ai_empty = _ai_rack.is_empty()

	if human_empty:
		var bonus = Tiles.get_rack_value(_ai_rack.get_tiles())
		_human_score += bonus
		_set_status("You used all your tiles! +%d bonus" % bonus)
		_update_display()
		await get_tree().create_timer(0.8).timeout
		_end_game("You win! %d - %d" % [_human_score, _ai_score])
		return true

	if ai_empty:
		var bonus = Tiles.get_rack_value(_human_rack.get_tiles())
		_ai_score += bonus
		_set_status("AI used all its tiles! +%d bonus" % bonus)
		_update_display()
		await get_tree().create_timer(0.8).timeout
		_end_game("AI wins! %d - %d" % [_ai_score, _human_score])
		return true

	return false


func _end_game(reason: String):
	_state = GameState.GAME_OVER
	SaveManager.delete_save(_save_slot)
	_save_slot = -1
	_set_status(reason)
	submit_button.disabled = true
	pass_button.disabled = true
	exchange_button.disabled = true
	rack_display.set_exchange_mode(false)

	if _human_score > _ai_score:
		_set_status("You win! %d - %d" % [_human_score, _ai_score])
	elif _ai_score > _human_score:
		_set_status("AI wins! %d - %d" % [_human_score, _ai_score])
	else:
		_set_status("Tie! %d - %d" % [_human_score, _ai_score])

	await get_tree().create_timer(0.5).timeout
	game_overlay.show_scores(_human_score, _ai_score)


func _on_board_cell_clicked(row: int, col: int):
	if _state != GameState.HUMAN_TURN or not _my_turn:
		return
	if _exchange_mode:
		return
	if _board.is_occupied(row, col):
		return

	var pending_idx = _get_pending_idx(row, col)
	if pending_idx >= 0:
		var pp = _pending_placements[pending_idx]
		_placed_rack_indices.erase(pp.rack_index)
		_pending_placements.remove_at(pending_idx)
		_selected_rack_index = -1
		_preview_dirty = true
		rack_display.clear_selection()
		_update_display()
		return

	if _selected_rack_index < 0:
		return

	if _placed_rack_indices.has(_selected_rack_index):
		return

	(
		_pending_placements
		. append(
			{
				pos = Vector2i(row, col),
				letter = _human_rack.get_tiles()[_selected_rack_index],
				rack_index = _selected_rack_index,
			}
		)
	)
	_placed_rack_indices.append(_selected_rack_index)
	_selected_rack_index = -1
	_preview_dirty = true
	rack_display.clear_selection()
	_update_display()


func _on_rack_tile_selected(index: int):
	if _state != GameState.HUMAN_TURN or not _my_turn:
		return
	if _placed_rack_indices.has(index):
		return
	if _exchange_mode:
		rack_display.toggle_exchange_index(index)
		_update_display()
		return
	_selected_rack_index = index


func _on_rack_tile_deselected():
	if _state != GameState.HUMAN_TURN or not _my_turn:
		return
	if not _exchange_mode:
		_selected_rack_index = -1


func _on_placed_tile_clicked(index: int):
	if _state != GameState.HUMAN_TURN or not _my_turn:
		return

	var rack_str = _human_rack.get_tiles()
	var letter = rack_str[index] if index < rack_str.length() else ""
	if letter.is_empty():
		return

	for i in range(_pending_placements.size() - 1, -1, -1):
		if _pending_placements[i].rack_index == index:
			_pending_placements.remove_at(i)

	_placed_rack_indices.erase(index)
	_preview_dirty = true
	_update_display()


func _on_submit():
	if _state != GameState.HUMAN_TURN or not _my_turn:
		return
	if _pending_placements.is_empty():
		_set_status("Place tiles on the board first")
		return

	var result = _validate_move()
	if not result.valid:
		_set_status(result.reason)
		return

	if _online_mode:
		if Net.is_host:
			_online.apply_human_move(result)
		else:
			_online.send_guest_action({"type": "play", "tiles": _online.serialize_placements()})
		return

	_apply_human_move(result)


func _on_pass():
	if _state != GameState.HUMAN_TURN or not _my_turn:
		return

	if _online_mode:
		if Net.is_host:
			_online.host_pass()
		else:
			_online.send_guest_action({"type": "pass"})
		return

	_consecutive_passes += 1
	_pending_placements = []
	_placed_rack_indices = []
	_selected_rack_index = -1
	rack_display.clear_selection()
	_set_status("You passed")
	_auto_save()

	if await _check_end_game():
		return

	_start_ai_turn()


func _on_exchange():
	if _state != GameState.HUMAN_TURN or not _my_turn:
		return

	if not _exchange_mode:
		var bag_empty := false
		if _online_mode and not Net.is_host:
			bag_empty = _bag_count <= 0
		else:
			bag_empty = _bag.is_empty()
		if bag_empty:
			_set_status("No tiles left in the bag to exchange")
			return
		_exchange_mode = true
		rack_display.set_exchange_mode(true)
		_set_status("Select tiles to exchange, then click Exchange again")
		_update_display()
		return

	var exchange_indices = rack_display.get_exchange_indices()
	if exchange_indices.is_empty():
		_exchange_mode = false
		rack_display.set_exchange_mode(false)
		_set_status("Exchange cancelled")
		_update_display()
		return

	var exchange_letters := ""
	var indices = exchange_indices.duplicate()
	indices.sort()
	indices.reverse()

	for i in indices:
		var rack_str = _human_rack.get_tiles()
		if i < rack_str.length():
			exchange_letters += rack_str[i]

	_exchange_mode = false
	rack_display.set_exchange_mode(false)
	_set_status("Exchanged %d tiles" % exchange_letters.length())

	if _online_mode:
		if Net.is_host:
			_online.host_exchange(exchange_letters)
		else:
			_online.send_guest_action({"type": "exchange", "letters": exchange_letters})
		return

	for c in exchange_letters:
		_human_rack.remove_letter(c)

	var new_tiles = _bag.exchange(exchange_letters)
	_human_rack.add_tiles(new_tiles)

	_update_display()
	_auto_save()

	if await _check_end_game():
		return

	_start_ai_turn()


func _validate_move() -> Dictionary:
	var tiles = _pending_placements
	if tiles.is_empty():
		return {valid = false, reason = "No tiles placed"}

	var positions: Array[Vector2i] = []
	for t in tiles:
		positions.append(t.pos)

	var rows := {}
	var cols := {}
	for p in positions:
		rows[p.x] = true
		cols[p.y] = true

	var horizontal := rows.size() == 1
	var vertical := cols.size() == 1

	if not horizontal and not vertical:
		return {valid = false, reason = "Tiles must be in a single row or column"}

	if horizontal and vertical and positions.size() == 1:
		horizontal = true

	var sorted = positions.duplicate()
	var fail_reason := ""

	if horizontal:
		sorted.sort_custom(func(a, b): return a.y < b.y)
		var row = sorted[0].x
		for i in range(1, sorted.size()):
			for gap in range(sorted[i - 1].y + 1, sorted[i].y):
				if _board.is_empty_at(row, gap):
					fail_reason = "No gaps allowed between placed tiles"
					break
			if not fail_reason.is_empty():
				break
	else:
		sorted.sort_custom(func(a, b): return a.x < b.x)
		var col = sorted[0].y
		for i in range(1, sorted.size()):
			for gap in range(sorted[i - 1].x + 1, sorted[i].x):
				if _board.is_empty_at(gap, col):
					fail_reason = "No gaps allowed between placed tiles"
					break
			if not fail_reason.is_empty():
				break

	if (
		fail_reason.is_empty()
		and not _board.is_move_connected(sorted[0].x, sorted[0].y, horizontal, positions)
	):
		fail_reason = "Word must connect to existing tiles on the board"

	var temp: Board = null
	if fail_reason.is_empty():
		temp = _board.duplicate()
		for t in tiles:
			temp.place_tile(t.pos.x, t.pos.y, t.letter)

		var start_row: int = sorted[0].x
		var start_col: int = sorted[0].y

		if horizontal:
			while start_col > 0 and temp.is_occupied(start_row, start_col - 1):
				start_col -= 1
		else:
			while start_row > 0 and temp.is_occupied(start_row - 1, start_col):
				start_row -= 1

		var main_word = temp.get_existing_word(start_row, start_col, horizontal)
		if main_word.word.length() < 2:
			fail_reason = "Word must be at least 2 letters long"
		elif not _is_word_valid(main_word.word):
			fail_reason = '"%s" is not a valid word' % main_word.word
		else:
			for t in tiles:
				var cross = temp.get_existing_word(t.pos.x, t.pos.y, not horizontal)
				if cross.word.length() > 1 and not _is_word_valid(cross.word):
					fail_reason = '"%s" is not a valid word' % cross.word
					break

			if fail_reason.is_empty():
				var tiles_placed_arr: Array[Vector2i] = []
				for t in tiles:
					tiles_placed_arr.append(t.pos)

				var score = Scoring.calculate(
					temp, main_word.word, main_word.row, main_word.col, horizontal, tiles_placed_arr
				)

				return {
					valid = true,
					word = main_word.word,
					row = main_word.row,
					col = main_word.col,
					horizontal = horizontal,
					score = score,
					tiles_placed = tiles_placed_arr,
				}

	return {valid = false, reason = fail_reason}


func _get_pending_idx(row: int, col: int) -> int:
	for i in range(_pending_placements.size()):
		if _pending_placements[i].pos.x == row and _pending_placements[i].pos.y == col:
			return i
	return -1


func _update_display():
	var preview_board = _board.duplicate()
	for pp in _pending_placements:
		preview_board.place_tile(pp.pos.x, pp.pos.y, pp.letter)

	if _pending_placements.is_empty():
		_preview_valid_cache = false
		_preview_dirty = false
	elif _preview_dirty:
		_preview_valid_cache = _validate_move().valid
		_preview_dirty = false

	board_display.display(preview_board, _get_pending_positions(), _preview_valid_cache)
	rack_display.display(_human_rack.get_tiles(), _selected_rack_index, _placed_rack_indices)

	player_score_label.text = "You: %d" % _human_score
	if _online_mode:
		ai_score_label.text = "Opponent: %d" % _ai_score
	else:
		ai_score_label.text = "AI: %d" % _ai_score

	submit_button.disabled = not (
		_state == GameState.HUMAN_TURN and _my_turn and not _pending_placements.is_empty()
	)
	pass_button.disabled = not (_state == GameState.HUMAN_TURN and _my_turn)
	exchange_button.disabled = not (_state == GameState.HUMAN_TURN and _my_turn)

	var exchange_count = rack_display.get_exchange_indices().size() if _exchange_mode else 0
	if _exchange_mode:
		exchange_button.text = "Confirm (%d)" % exchange_count
	else:
		exchange_button.text = "Exchange"


func _get_pending_positions() -> Array:
	var result: Array[Vector2i] = []
	for pp in _pending_placements:
		result.append(pp.pos)
	return result


func _set_status(msg: String):
	status_label.text = msg


func _assign_save_slot() -> int:
	for i in range(SaveManager.MAX_SLOTS):
		if not SaveManager.has_save(i):
			return i
	var saves = SaveManager.get_save_list()
	if saves.is_empty():
		return 0
	saves.sort_custom(func(a, b): return a.timestamp < b.timestamp)
	return saves[0].slot


func _collect_save_data() -> Dictionary:
	var cells := []
	for r in range(15):
		var row := []
		for c in range(15):
			row.append(_board.get_tile(r, c) if _board.is_occupied(r, c) else null)
		cells.append(row)

	return {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"difficulty": _difficulty,
		"difficulty_name": _get_difficulty_name(),
		"board": cells,
		"bag_pool": _bag._pool.duplicate(),
		"human_rack": _human_rack.get_tiles(),
		"ai_rack": _ai_rack.get_tiles(),
		"human_score": _human_score,
		"ai_score": _ai_score,
		"consecutive_passes": _consecutive_passes,
	}


func _get_difficulty_name() -> String:
	match _difficulty:
		AIPlayer.Difficulty.EASY:
			return "Easy"
		AIPlayer.Difficulty.MEDIUM:
			return "Medium"
		AIPlayer.Difficulty.HARD:
			return "Hard"
	return "Unknown"


func _apply_save_data(slot: int, data: Dictionary) -> void:
	_save_slot = slot
	_difficulty = data.get("difficulty", AIPlayer.Difficulty.HARD)

	_board = Board.new()
	var board_data = data.get("board", [])
	for r in range(board_data.size()):
		var row = board_data[r]
		for c in range(row.size()):
			if row[c] != null:
				_board.place_tile(r, c, row[c])

	_bag = TileBag.new()
	_bag._pool = data.get("bag_pool", []).duplicate()

	_human_rack = TileRack.new(data.get("human_rack", ""))
	_ai_rack = TileRack.new(data.get("ai_rack", ""))
	_human_score = data.get("human_score", 0)
	_ai_score = data.get("ai_score", 0)
	_consecutive_passes = data.get("consecutive_passes", 0)
	_reset_turn_state()

	if not WordDict.is_ready:
		_set_status("Loading dictionary...")
		await WordDict.dictionary_ready

	if WordDict.trie == null:
		push_error("Game: word dictionary is not ready; AI and word validation will not work")
		_set_status("Dictionary failed to load")
		return

	var mg = MoveGenerator.new()
	_ai_player = AIPlayer.new(_difficulty, mg, WordDict.trie)

	difficulty_panel.visible = false
	game_ui.visible = true
	game_overlay.visible = false
	await _resize_board()
	_update_display()
	_start_human_turn()


func _auto_save() -> void:
	if _save_slot < 0:
		return
	var data = _collect_save_data()
	SaveManager.save_data(_save_slot, data)


func _on_play_again():
	game_overlay.hide()
	if _online_mode:
		if Net.is_host:
			_online.start_online_game()
		else:
			_online.send_guest_action({"type": "rematch"})
		return
	_save_slot = _assign_save_slot()
	_start_game()
	_auto_save()


func _on_theme_toggle():
	Settings.dark_mode = not Settings.dark_mode


func _on_theme_changed(dark: bool):
	_apply_background(dark)
	_update_theme_button(dark)
	_style_scene_theme(dark)


func _apply_background(dark: bool):
	background.color = Color(0.08, 0.08, 0.15, 1) if dark else Color(0.93, 0.90, 0.83, 1)


func _update_theme_button(dark: bool):
	theme_button.text = "LIGHT" if dark else "DARK"


func _style_scene_theme(dark: bool):
	var btn_style = _make_style(
		Color(0.13, 0.13, 0.24, 1) if dark else Color(0.88, 0.84, 0.78, 1),
		Color(0.91, 0.27, 0.38, 1),
		10
	)
	var top_style = _make_style(
		Color(0.13, 0.13, 0.24, 1) if dark else Color(0.88, 0.84, 0.78, 1),
		Color(0.91, 0.27, 0.38, 1),
		8
	)
	var panel_style = _make_style(
		Color(0.11, 0.11, 0.20, 0.95) if dark else Color(0.98, 0.97, 0.95, 0.95),
		Color(0.91, 0.27, 0.38, 1),
		16
	)

	%DifficultyPanel.add_theme_stylebox_override("panel", panel_style)
	game_overlay.get_node("OverlayPanel").add_theme_stylebox_override("panel", panel_style)

	var btn_font: Color = Color(1, 1, 1, 1) if dark else Color(0.08, 0.06, 0.12, 1)
	var btn_hover: Color = Color(0.91, 0.27, 0.38, 1)
	var muted_font: Color = Color(0.75, 0.75, 0.85, 1) if dark else Color(0.40, 0.40, 0.50, 1)
	var body_font: Color = Color(0.85, 0.85, 0.92, 1) if dark else Color(0.35, 0.38, 0.44, 1)
	var accent_font: Color = Color(0.91, 0.27, 0.38, 1)

	for b in [%EasyButton, %MediumButton, %HardButton, %SubmitButton, %PassButton, %ExchangeButton]:
		b.add_theme_stylebox_override("normal", btn_style)
		b.add_theme_stylebox_override("hover", btn_style)
		b.add_theme_stylebox_override("pressed", btn_style)
		b.add_theme_color_override("font_color", btn_font)
		b.add_theme_color_override("font_hover_color", btn_hover)

	for b in [%ThemeButton, %MenuButton]:
		b.add_theme_stylebox_override("normal", top_style)
		b.add_theme_stylebox_override("hover", top_style)
		b.add_theme_stylebox_override("pressed", top_style)
		b.add_theme_color_override("font_color", body_font)
		b.add_theme_color_override("font_hover_color", btn_hover)

	var back_btn = %DifficultyPanel.get_node("DifficultyVBox/BackMenuButton")
	back_btn.add_theme_stylebox_override("normal", btn_style)
	back_btn.add_theme_stylebox_override("hover", btn_style)
	back_btn.add_theme_stylebox_override("pressed", btn_style)
	back_btn.add_theme_color_override("font_color", muted_font)
	back_btn.add_theme_color_override("font_hover_color", btn_hover)

	for path_and_is_muted in [
		["OverlayPanel/OverlayVBox/PlayAgainButton", false],
		["OverlayPanel/OverlayVBox/MainMenuButton", false],
	]:
		var ob = game_overlay.get_node(path_and_is_muted[0])
		ob.add_theme_stylebox_override("normal", btn_style)
		ob.add_theme_stylebox_override("hover", btn_style)
		ob.add_theme_stylebox_override("pressed", btn_style)
		ob.add_theme_color_override("font_color", btn_font)
		ob.add_theme_color_override("font_hover_color", btn_hover)

	var diff_title = %DifficultyPanel.get_node("DifficultyVBox/DiffTitle")
	diff_title.add_theme_color_override("font_color", accent_font)

	var diff_sub = %DifficultyPanel.get_node("DifficultyVBox/DiffSubtitle")
	diff_sub.add_theme_color_override("font_color", body_font)

	%PlayerScore.add_theme_color_override("font_color", Color(0.24, 0.67, 0.36, 1) if dark else Color(0.20, 0.58, 0.30, 1))
	%AIScore.add_theme_color_override("font_color", Color(0.91, 0.27, 0.38, 1))
	%StatusLabel.add_theme_color_override("font_color", body_font)

	var overlay_title = game_overlay.get_node("OverlayPanel/OverlayVBox/GameOverTitle")
	overlay_title.add_theme_color_override("font_color", accent_font)

	var overlay_scores = game_overlay.get_node("OverlayPanel/OverlayVBox/FinalScores")
	overlay_scores.add_theme_color_override("font_color", Color(1, 1, 1, 1) if dark else Color(0.08, 0.06, 0.12, 1))

	var overlay_bg = game_overlay.get_node("OverlayBg")
	overlay_bg.color = Color(0.06, 0.06, 0.14, 0.78) if dark else Color(0.93, 0.90, 0.83, 0.88)


func _make_style(bg: Color, border: Color, radius: float) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.border_color = border
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_right = radius
	s.corner_radius_bottom_left = radius
	return s


func _on_main_menu():
	if not _online_mode:
		_auto_save()
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")


func _exit_tree() -> void:
	if _online_mode:
		Net.teardown()
