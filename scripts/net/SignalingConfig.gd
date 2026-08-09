class_name SignalingConfig
extends RefCounted

const DEFAULT_URL := "wss://scrabble-signal.iliafe020.deno.net/"


static func get_url() -> String:
	var env := OS.get_environment("SCRABBLE_SIGNALING_URL")
	return env if not env.is_empty() else DEFAULT_URL
