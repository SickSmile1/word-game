extends GutTest

const GameSession = preload("res://scripts/game/GameSession.gd")
const GameScene := preload("res://scenes/game/Game.tscn")


func test_host_snapshot_guest_restore_roundtrip():
	var host := GameSession.new()
	host.new_game()
	host.board.place_tile(7, 7, "A")
	host.turn = GameSession.Player.P1
	var payload := host.to_dict_for_player(GameSession.Player.P1)
	var guest := GameSession.from_dict_for_player(payload, GameSession.Player.P1)
	assert_true(guest.board.is_occupied(7, 7))
	assert_eq(guest.bag_pool, [], "guest never holds bag")
	assert_eq(guest.racks[GameSession.Player.P1], host.racks[GameSession.Player.P1])
	assert_eq(guest.turn, GameSession.Player.P1)


func test_guest_turn_render_when_its_not_your_turn():
	var s := GameSession.new()
	s.new_game()
	s.turn = GameSession.Player.P0  # host's turn
	var payload := s.to_dict_for_player(GameSession.Player.P1)
	var guest := GameSession.from_dict_for_player(payload, GameSession.Player.P1)
	assert_eq(guest.turn, GameSession.Player.P0)
	# (mirrors Game._on_net_state: _my_turn = (s.turn == me))
	var me := GameSession.Player.P1
	assert_false(guest.turn == me)


func test_game_scene_loads_with_online_script():
	assert_not_null(load("res://scripts/ui/GameOnline.gd"), "GameOnline.gd must exist")
	assert_not_null(GameScene, "Game.tscn must exist")


func test_game_scene_instantiates_offline():
	var game = GameScene.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	assert_not_null(game.get_node_or_null("%DifficultyPanel"), "DifficultyPanel must exist")
	assert_not_null(game.get_node_or_null("%SubmitButton"), "SubmitButton must exist")
	assert_false(game._online_mode, "offline path must not enable online mode")
