class_name SignalingConfig
extends RefCounted

const DEFAULT_URL := "wss://scrabble-signal.iliafe020.deno.net/"


static func get_url() -> String:
	if OS.has_feature("web"):
		var js_override = JavaScriptBridge.eval("window.SCRABBLE_SIGNALING_URL || ''")
		if js_override != null and not String(js_override).is_empty():
			return String(js_override)
	var env := OS.get_environment("SCRABBLE_SIGNALING_URL")
	return env if not env.is_empty() else DEFAULT_URL
