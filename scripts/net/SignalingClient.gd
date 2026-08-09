extends Node

signal host_connected(room_code: String, slot: int)
signal host_error(reason: String)
signal connection_open(pc: WebRTCPeerConnection)

const Config = preload("res://scripts/net/SignalingConfig.gd")

const ICE_SERVERS := {
	"iceServers": [
		{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]},
	],
}

var _ws: WebSocketPeer
var _pc: WebRTCPeerConnection
var _is_host := false
var _room := ""
var _sent_intent := false
var _remote_description_set := false
var _handshake_done := false
var _pending_candidates: Array[Dictionary] = []


func start_host(room: String = "") -> void:
	_is_host = true
	_room = room
	_connect()


func start_guest(room: String) -> void:
	_is_host = false
	_room = room
	_connect()


func _connect() -> void:
	_pc = WebRTCPeerConnection.new()
	_pc.initialize(ICE_SERVERS)
	_pc.session_description_created.connect(_on_session_created)
	_pc.ice_candidate_created.connect(_on_ice_candidate)
	_pc.connection_state_changed.connect(_on_connection_state)

	_ws = WebSocketPeer.new()
	_ws.connect_to_url(Config.get_url())


func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _sent_intent:
			_sent_intent = true
			_send(_build_intent())
		while _ws.get_available_packet_count() > 0:
			_handle_message(_ws.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED and not _handshake_done:
		host_error.emit("Signaling connection lost")


func _build_intent() -> Dictionary:
	return {"type": "create", "room": _room} if _is_host else {"type": "join", "room": _room}


func _handle_message(text: String) -> void:
	var data = JSON.parse_string(text)
	if data == null:
		return
	match data.type:
		"created", "joined":
			_room = data.room if data.has("room") else _room
			host_connected.emit(_room, data.slot)
			if _is_host:
				_pc.create_offer()
		"session":
			_pc.set_remote_description(data.subtype, data.sdp)
			_remote_description_set = true
			_flush_candidates()
			if data.subtype == "offer":
				_pc.create_answer()
		"candidate":
			if _remote_description_set:
				_pc.add_ice_candidate(data.mid, data.index, data.sdp)
			else:
				_pending_candidates.append(data)
		"error":
			host_error.emit(data.reason)


func _on_session_created(subtype: String, sdp: String) -> void:
	_pc.set_local_description(subtype, sdp)
	_send({"type": "session", "subtype": subtype, "sdp": sdp})


func _on_ice_candidate(mid: String, index: int, sdp: String) -> void:
	_send({"type": "candidate", "mid": mid, "index": index, "sdp": sdp})


func _on_connection_state(state: int) -> void:
	if state == WebRTCPeerConnection.STATE_CONNECTED:
		_handshake_done = true
		connection_open.emit(_pc)
	elif state == WebRTCPeerConnection.STATE_FAILED and not _handshake_done:
		host_error.emit("Peer connection failed — try again or check your network")


func _flush_candidates() -> void:
	for c in _pending_candidates:
		_pc.add_ice_candidate(c.mid, c.index, c.sdp)
	_pending_candidates.clear()


func _send(msg: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.put_packet(JSON.stringify(msg).to_utf8_buffer())


func close() -> void:
	if _ws != null:
		_ws.close()
		_ws = null
	if _pc != null:
		_pc.close()
		_pc = null
	_pending_candidates.clear()
