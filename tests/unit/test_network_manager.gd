extends GutTest

const SignalingConfig = preload("res://scripts/net/SignalingConfig.gd")
const SignalingClient = preload("res://scripts/net/SignalingClient.gd")

func test_env_url_override():
	OS.set_environment("SCRABBLE_SIGNALING_URL", "wss://example.test/")
	assert_eq(SignalingConfig.get_url(), "wss://example.test/")
	OS.set_environment("SCRABBLE_SIGNALING_URL", "")

func test_default_url_is_wss():
	OS.set_environment("SCRABBLE_SIGNALING_URL", "")
	assert_true(SignalingConfig.get_url().begins_with("wss://"), "signaling url must be wss")

func test_intent_message_builders():
	var client := SignalingClient.new()
	client._is_host = true
	var host_msg = JSON.parse_string(JSON.stringify(client._build_intent()))
	assert_eq(host_msg.type, "create", "host intent type")
	assert_eq(host_msg.room, "", "host intent room")
	client._is_host = false
	client._room = "123456"
	var guest_msg = JSON.parse_string(JSON.stringify(client._build_intent()))
	assert_eq(guest_msg.type, "join", "guest intent type")
	assert_eq(guest_msg.room, "123456", "guest intent room")
	client.free()
