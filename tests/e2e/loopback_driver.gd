extends Node

const GameSession = preload("res://scripts/game/GameSession.gd")

var _role := ""
var _code := ""
var _steps := 0
var _watchdog := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_role = args[0]
	if args.size() >= 2:
		_code = args[1]

	if _role != "host" and _role != "guest":
		print("usage: <host|guest> <room>")
		get_tree().quit(1)
		return

	Net.host_connected.connect(_on_host_connected)
	Net.state_received.connect(_on_state)
	Net.submit_action_received.connect(_on_action)
	Net.peer_connected.connect(_on_peer_connected)
	Net.peer_disconnected.connect(func(): print(_role, ": peer_disconnected"))
	Net.net_error.connect(_on_net_error)

	if _role == "host":
		Net.start_host(_code)
	else:
		Net.start_guest(_code)


func _process(delta: float) -> void:
	_watchdog += delta
	if _watchdog > 25.0:
		push_error(_role + ": TIMEOUT")
		get_tree().quit(1)


func _on_net_error(reason: String) -> void:
	push_error(_role + ": net_error: " + reason)
	get_tree().quit(1)


func _on_host_connected(room: String, _slot: int) -> void:
	print(_role, ": room=", room)


func _on_peer_connected() -> void:
	print(_role, ": peer_connected")
	if _role == "host":
		_broadcast_turn()


func _broadcast_turn() -> void:
	var s := GameSession.new()
	s.new_game()
	s.board.place_tile(7, 7, "A")
	s.turn = GameSession.Player.P1
	Net.send_state(s.to_dict_for_player(GameSession.Player.P1))
	print("host: sent state")


func _on_state(state: Dictionary) -> void:
	if _role != "guest":
		return
	print("guest: got state version=", state.get("version", -1))

	var s := GameSession.from_dict_for_player(state, GameSession.Player.P1)
	if not s.board.is_occupied(7, 7):
		push_error("guest: board tile missing")
		get_tree().quit(1)
		return
	if s.turn != GameSession.Player.P1:
		push_error("guest: wrong turn")
		get_tree().quit(1)
		return
	if not s.bag_pool.is_empty():
		push_error("guest: bag leaked to guest")
		get_tree().quit(1)
		return

	if _steps == 0:
		_steps = 1
		Net.send_action({"type": "pass"})
		print("guest: sent pass")
	else:
		print("guest: OK")
		get_tree().quit(0)


func _on_action(sender_id: int, action: Dictionary) -> void:
	if _role != "host":
		return
	print("host: got action from ", sender_id, " type=", action.get("type", ""))
	if sender_id != Net.remote_peer_id:
		push_error("host: unexpected sender " + str(sender_id))
		get_tree().quit(1)
		return
	if action.get("type") != "pass":
		push_error("host: unexpected action type")
		get_tree().quit(1)
		return

	_broadcast_turn()
	print("host: OK")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0)
