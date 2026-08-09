extends Node

signal session_started(host: bool)
signal peer_connected
signal peer_disconnected
signal net_error(reason: String)
signal host_connected(room_code: String, slot: int)
signal submit_action_received(sender_id: int, action: Dictionary)
signal state_received(state: Dictionary)

const SignalingClient = preload("res://scripts/net/SignalingClient.gd")

var active := false
var is_host := false
var remote_peer_id := 1
var _client: SignalingClient
var _mp: WebRTCMultiplayerPeer


func start_host(room_code: String) -> bool:
	_init_client(room_code, true)
	return true


func start_guest(room_code: String) -> bool:
	_init_client(room_code, false)
	return true


func _init_client(room_code: String, host: bool) -> void:
	is_host = host
	remote_peer_id = 2 if host else 1
	_client = SignalingClient.new()
	add_child(_client)
	_client.peer_created.connect(_on_peer_created)
	_client.host_connected.connect(_on_host_connected)
	_client.host_error.connect(_on_net_error)
	_client.connection_open.connect(_on_connection_open)
	if host:
		_client.start_host(room_code)
	else:
		_client.start_guest(room_code)


func _process(_delta: float) -> void:
	if _mp != null:
		_mp.poll()


func _on_peer_created(pc: WebRTCPeerConnection) -> void:
	print("[Net] Registering WebRTCPeerConnection with WebRTCMultiplayerPeer (is_host=%s)..." % is_host)
	_mp = WebRTCMultiplayerPeer.new()
	if is_host:
		_mp.create_server()
		_mp.add_peer(pc, remote_peer_id)
	else:
		_mp.create_client(2)
		_mp.add_peer(pc, 1)


func _on_host_connected(room: String, slot: int) -> void:
	host_connected.emit(room, slot)


func _on_connection_open(_pc: WebRTCPeerConnection) -> void:
	print("[Net] WebRTC Connected! Setting multiplayer.multiplayer_peer...")
	multiplayer.multiplayer_peer = _mp
	active = true
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	session_started.emit(is_host)


func _on_peer_connected(_id: int) -> void:
	peer_connected.emit()


func _on_peer_disconnected(_id: int) -> void:
	peer_disconnected.emit()


func _on_net_error(reason: String) -> void:
	net_error.emit(reason)


func send_action(action: Dictionary) -> void:
	if is_host:
		submit_action_received.emit(1, action)
	else:
		submit_action.rpc(action)


@rpc("any_peer", "reliable")
func submit_action(action: Dictionary) -> void:
	submit_action_received.emit(multiplayer.get_remote_sender_id(), action)


func send_state(state: Dictionary) -> void:
	rpc_id(remote_peer_id, "receive_state", state)


@rpc("authority", "call_remote", "reliable")
func receive_state(state: Dictionary) -> void:
	state_received.emit(state)


func teardown() -> void:
	active = false
	if _mp != null:
		multiplayer.multiplayer_peer = null
		_mp = null
	if _client != null:
		_client.close()
		_client.queue_free()
		_client = null
