class_name GameOnline
extends RefCounted

const GameSession = preload("res://scripts/game/GameSession.gd")
const TileRack = preload("res://scripts/game/TileRack.gd")
const TileBag = preload("res://scripts/game/TileBag.gd")
const Tiles = preload("res://scripts/game/Tiles.gd")

var game: Control


func _init(game_node: Control) -> void:
	game = game_node


func setup() -> void:
	Net.state_received.connect(_on_net_state)
	Net.peer_disconnected.connect(_on_net_disconnect)
	if Net.is_host:
		Net.submit_action_received.connect(_on_net_action)
		start_online_game()
	else:
		if game._board == null:
			game._board = Board.new()
		game._my_turn = false
		game._state = game.GameState.WAITING
		game._set_status("Waiting for host…")
		game._update_display()


func start_online_game() -> void:
	if not WordDict.is_ready:
		game._set_status("Loading dictionary...")
		await WordDict.dictionary_ready
	if WordDict.trie == null:
		push_error("Game: word dictionary is not ready; online validation will not work")
		game._set_status("Dictionary failed to load — cannot start game")
		return

	var s := GameSession.new()
	s.new_game()
	_session_into_fields(s)
	game._my_turn = true
	game._state = game.GameState.HUMAN_TURN
	game._reset_turn_state()
	game._set_status("Your turn")
	game._update_display()
	Net.send_state(_build_guest_state())


func _session_into_fields(s: GameSession) -> void:
	game._board = s.board
	game._bag = TileBag.new()
	game._bag._pool = s.bag_pool.duplicate()
	game._bag_count = s.bag_pool.size()
	game._human_rack = TileRack.new(s.racks[GameSession.Player.P0])
	game._ai_rack = TileRack.new(s.racks[GameSession.Player.P1])
	game._human_score = s.scores[GameSession.Player.P0]
	game._ai_score = s.scores[GameSession.Player.P1]
	game._consecutive_passes = s.consecutive_passes
	game._reset_turn_state()


func _fields_into_session(s: GameSession) -> void:
	s.board = game._board
	s.bag_pool = game._bag._pool.duplicate()
	s.racks[GameSession.Player.P0] = game._human_rack.get_tiles()
	s.racks[GameSession.Player.P1] = game._ai_rack.get_tiles()
	s.scores = [game._human_score, game._ai_score]
	s.consecutive_passes = game._consecutive_passes
	s.turn = GameSession.Player.P0 if game._my_turn else GameSession.Player.P1


func _build_guest_state() -> Dictionary:
	var s := GameSession.new()
	_fields_into_session(s)
	s.game_over = game._state == game.GameState.GAME_OVER
	return s.to_dict_for_player(GameSession.Player.P1)


func serialize_placements() -> Array:
	var arr: Array = []
	for pp in game._pending_placements:
		arr.append({
			"row": int(pp.pos.x),
			"col": int(pp.pos.y),
			"pos": {"x": int(pp.pos.x), "y": int(pp.pos.y)},
			"letter": String(pp.letter),
			"rack_index": int(pp.rack_index),
		})
	return arr


func send_guest_action(action: Dictionary) -> void:
	print("[Net] Guest sending action to Host: ", action)
	Net.send_action(action)
	game._reset_turn_state()
	game._state = game.GameState.WAITING
	game._my_turn = false
	game._update_display()


func _on_net_action(sender_id: int, action: Dictionary) -> void:
	if not Net.is_host:
		return
	if sender_id != Net.remote_peer_id:
		print("[Net] Host ignoring action from unknown sender %d (remote_peer_id=%d)" % [sender_id, Net.remote_peer_id])
		return
	if game._my_turn:
		print("[Net] Host ignoring action because it is currently Host's turn")
		return

	print("[Net] Host received action from sender %d: %s" % [sender_id, action])

	match action.get("type", ""):
		"play":
			if not WordDict.is_ready:
				print("[Net] Host waiting for dictionary before validating guest move...")
				game._set_status("Loading dictionary...")
				await WordDict.dictionary_ready
			game._pending_placements = []
			for t in action.get("tiles", []):
				if not (t is Dictionary):
					continue
				var px := 0
				var py := 0
				if t.has("row") and t.has("col"):
					px = int(t.get("row", 0))
					py = int(t.get("col", 0))
				elif t.has("pos"):
					var pos_val = t.get("pos")
					if pos_val is Dictionary:
						px = int(pos_val.get("x", 0))
						py = int(pos_val.get("y", 0))
					elif pos_val is Vector2i:
						px = pos_val.x
						py = pos_val.y
					elif pos_val is Vector2:
						px = int(pos_val.x)
						py = int(pos_val.y)

				game._pending_placements.append({
					pos = Vector2i(px, py),
					letter = String(t.get("letter", "")),
					rack_index = int(t.get("rack_index", 0)),
				})
			print("[Net] Host evaluating guest pending placements: ", game._pending_placements)
			var result = game._validate_move()
			print("[Net] Host move validation result: valid=%s, reason=\"%s\", word=\"%s\"" % [result.valid, result.get("reason", ""), result.get("word", "")])
			if not result.valid:
				print("[Net] Host move validation REJECTED guest move: ", result.reason)
				var fail_msg: String = "Move rejected: " + String(result.reason)
				game._set_status(fail_msg)
				_broadcast(fail_msg)
				return
			print("[Net] Host move validation ACCEPTED guest move: word=\"%s\" score=%d orientation=%s tiles=%s" % [result.word, result.score, ("horizontal" if result.horizontal else "vertical"), result.tiles_placed])
			_apply_guest_move_online(result)
		"pass":
			print("[Net] Host processing guest pass")
			game._consecutive_passes += 1
			game._reset_turn_state()
			var msg := "Opponent passed"
			game._set_status(msg)
			game._state = game.GameState.HUMAN_TURN
			game._my_turn = true
			game._update_display()
			_check_end_game_online()
			_broadcast(msg)
		"exchange":
			var letters: String = action.get("letters", "")
			print("[Net] Host processing guest exchange: %d letters" % letters.length())
			for c in letters:
				game._ai_rack.remove_letter(c)
			game._ai_rack.add_tiles(game._bag.exchange(letters))
			game._reset_turn_state()
			var msg := "Opponent exchanged %d tiles" % letters.length()
			game._set_status(msg)
			game._state = game.GameState.HUMAN_TURN
			game._my_turn = true
			game._update_display()
			_check_end_game_online()
			_broadcast(msg)
		"rematch":
			print("[Net] Host restarting game for rematch")
			start_online_game()


func apply_human_move(result: Dictionary) -> void:
	var word = result.word
	var score = result.score

	for pp in game._pending_placements:
		game._board.place_tile(pp.pos.x, pp.pos.y, pp.letter)
		game._human_rack.remove_letter(pp.letter)

	game._human_score += score
	game._pending_placements = []
	game._placed_rack_indices = []
	game._selected_rack_index = -1
	game._consecutive_passes = 0
	var msg := '"%s" scores %d!' % [word, score]
	print("[Net] Host applied host move: %s. Scores - Host: %d, Guest: %d" % [msg, game._human_score, game._ai_score])
	game._set_status(msg)
	game._draw_human_tiles()
	game._state = game.GameState.WAITING
	game._my_turn = false
	game._update_display()
	_check_end_game_online()
	_broadcast(msg)


func host_pass() -> void:
	print("[Net] Host passed turn")
	game._consecutive_passes += 1
	game._reset_turn_state()
	var msg := "You passed"
	game._set_status(msg)
	game._state = game.GameState.WAITING
	game._my_turn = false
	game._update_display()
	_check_end_game_online()
	_broadcast(msg)


func host_exchange(letters: String) -> void:
	print("[Net] Host exchanged %d tiles" % letters.length())
	for c in letters:
		game._human_rack.remove_letter(c)
	game._human_rack.add_tiles(game._bag.exchange(letters))
	game._state = game.GameState.WAITING
	game._my_turn = false
	game._update_display()
	_check_end_game_online()
	var msg := "Host exchanged %d tiles" % letters.length()
	_broadcast(msg)


func _apply_guest_move_online(result: Dictionary) -> void:
	var word = result.word
	var score = result.score

	for pp in game._pending_placements:
		game._board.place_tile(pp.pos.x, pp.pos.y, pp.letter)
		game._ai_rack.remove_letter(pp.letter)

	game._ai_score += score
	game._pending_placements = []
	game._placed_rack_indices = []
	game._selected_rack_index = -1
	game._consecutive_passes = 0
	var msg := 'Opponent played "%s" for %d' % [word, score]
	print("[Net] Host applied guest move: %s. Scores - Host: %d, Guest: %d" % [msg, game._human_score, game._ai_score])
	game._set_status(msg)
	game._draw_ai_tiles()
	game._state = game.GameState.HUMAN_TURN
	game._my_turn = true
	game._update_display()
	_check_end_game_online()
	_broadcast(msg)


func _check_end_game_online() -> bool:
	if game._consecutive_passes >= 6:
		_end_game_online("Both players passed 3 times! Game over.")
		return true

	var human_empty = game._human_rack.is_empty()
	var guest_empty = game._ai_rack.is_empty()

	if human_empty:
		var human_bonus = Tiles.get_rack_value(game._ai_rack.get_tiles())
		game._human_score += human_bonus
		_end_game_online("You used all your tiles! +%d bonus" % human_bonus)
		return true

	if guest_empty:
		var guest_bonus = Tiles.get_rack_value(game._human_rack.get_tiles())
		game._ai_score += guest_bonus
		_end_game_online("Opponent used all their tiles! +%d bonus" % guest_bonus)
		return true

	return false


func _end_game_online(reason: String) -> void:
	print("[Net] Game over: ", reason)
	game._state = game.GameState.GAME_OVER
	game._set_status(reason)
	game.submit_button.disabled = true
	game.pass_button.disabled = true
	game.exchange_button.disabled = true
	game.rack_display.set_exchange_mode(false)
	game.rack_display.clear_selection()
	game._update_display()
	game.game_overlay.show_scores(game._human_score, game._ai_score, "You", "Opponent")


func _on_net_state(state: Dictionary) -> void:
	if Net.is_host:
		return

	var me := GameSession.Player.P1
	var s := GameSession.from_dict_for_player(state, me)
	game._board = s.board
	game._bag = TileBag.new()
	game._bag_count = s.bag_count
	game._human_rack = TileRack.new(s.racks[me])
	game._ai_rack = TileRack.new(s.racks[GameSession.Player.P0])
	game._human_score = s.scores[me]
	game._ai_score = s.scores[GameSession.Player.P0]
	game._consecutive_passes = s.consecutive_passes
	game._my_turn = (s.turn == me)
	game._state = game.GameState.HUMAN_TURN if game._my_turn else game.GameState.WAITING
	game._reset_turn_state()
	if not s.last_action_text.is_empty():
		game._set_status(s.last_action_text)
	else:
		game._set_status("Your turn" if game._my_turn else "Opponent's turn")
	game._update_display()

	print("[Net] Guest received state update: my_turn=%s, scores=[Host:%d, Guest:%d], last_action=\"%s\"" % [game._my_turn, s.scores[GameSession.Player.P0], s.scores[GameSession.Player.P1], s.last_action_text])

	if s.game_over:
		_end_game_online("Game over")


func _on_net_disconnect() -> void:
	print("[Net] Opponent disconnected!")
	game._set_status("Opponent disconnected")
	game.submit_button.disabled = true
	game.pass_button.disabled = true
	game.exchange_button.disabled = true
	game._state = game.GameState.GAME_OVER
	Net.teardown()
	await game.get_tree().create_timer(1.5).timeout
	game.get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")


func _broadcast(msg: String = "") -> void:
	var state_dict := _build_guest_state()
	if not msg.is_empty():
		state_dict["last_action"] = msg
	print("[Net] Host broadcasting state: turn=%s, msg=\"%s\"" % [("Host" if game._my_turn else "Guest"), msg])
	Net.send_state(state_dict)
