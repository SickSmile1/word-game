extends GutTest

const GameSession = preload("res://scripts/game/GameSession.gd")

func _session() -> GameSession:
	var s := GameSession.new()
	s.new_game()
	return s

func test_new_game_draws_racks_and_host_starts():
	var s := _session()
	assert_eq(s.racks[0].length(), 7)
	assert_eq(s.racks[1].length(), 7)
	assert_eq(s.turn, GameSession.Player.P0)
	assert_eq(s.scores, [0, 0])
	assert_false(s.game_over)

func test_self_snapshot_is_full_fidelity():
	var s := _session()
	var data := s.to_dict_for_player(GameSession.Player.P0)
	assert_true(data.has("bag"), "host snapshot must include bag")
	assert_eq(data.bag.size(), s.bag_pool.size())
	assert_eq(data.racks[0], s.racks[0])
	assert_eq(data.racks[1], s.racks[1])
	var restored := GameSession.from_dict_for_player(data, GameSession.Player.P0)
	assert_eq(restored.racks[0], s.racks[0])
	assert_eq(restored.racks[1], s.racks[1])
	assert_eq(restored.bag_pool, s.bag_pool)
	assert_eq(restored.turn, s.turn)
	assert_eq(restored.scores, s.scores)

func test_guest_snapshot_redacts_host_rack_and_bag():
	var s := _session()
	var data := s.to_dict_for_player(GameSession.Player.P1)
	assert_false(data.has("bag"), "guest snapshot must NOT include bag contents")
	assert_eq(data.bag_count, s.bag_pool.size(), "guest sees only bag count")
	assert_eq(data.racks[0], "*".repeat(s.racks[0].length()), "host rack masked")
	assert_eq(data.racks[1], s.racks[1], "guest sees own rack in full")
	assert_eq(data.board.size(), 15)
	assert_eq(data.version, GameSession.PROTOCOL_VERSION)

func test_guest_restore_never_materializes_bag():
	var s := _session()
	var data := s.to_dict_for_player(GameSession.Player.P1)
	var guest := GameSession.from_dict_for_player(data, GameSession.Player.P1)
	assert_eq(guest.bag_pool, [], "guest must not hold bag tiles")
	assert_eq(guest.bag_count, data.bag_count)

func test_round_trip_keeps_scores_passes_and_game_over():
	var s := _session()
	s.scores = [42, 7]
	s.consecutive_passes = 2
	s.turn = GameSession.Player.P1
	s.game_over = true
	var data := s.to_dict_for_player(GameSession.Player.P1)
	var restored := GameSession.from_dict_for_player(data, GameSession.Player.P1)
	assert_eq(restored.scores, [42, 7])
	assert_eq(restored.consecutive_passes, 2)
	assert_eq(restored.turn, GameSession.Player.P1)
	assert_true(restored.game_over)
