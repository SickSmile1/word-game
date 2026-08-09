class_name AudioManager
extends Node

enum Bus { MASTER = 0, MUSIC = 1, EFFECTS = 2 }

var _tween: Tween
var _music_player: AudioStreamPlayer2D


func _ready() -> void:
	Settings.music_volume_changed.connect(_on_music_volume_changed)
	Settings.effects_volume_changed.connect(_on_effects_volume_changed)
	Settings.overall_volume_changed.connect(_on_overall_volume_changed)


func play_sfx(sound: AudioStream, bus: Bus = Bus.EFFECTS) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = sound
	player.bus = _bus_name(bus)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func play_music(sound: AudioStream, loop: bool = true) -> void:
	if _music_player == null:
		_music_player = AudioStreamPlayer2D.new()
		_music_player.bus = _bus_name(Bus.MUSIC)
		add_child(_music_player)

	_music_player.stop()
	_music_player.stream = sound

	var connected := _music_player.finished.is_connected(_on_music_finished)
	if loop and not connected:
		_music_player.finished.connect(_on_music_finished)
	elif not loop and connected:
		_music_player.finished.disconnect(_on_music_finished)

	_music_player.play()


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


func set_bus_volume(bus: Bus, linear_value: float) -> void:
	var db := linear_to_db(linear_value)
	AudioServer.set_bus_volume_db(bus, db)
	AudioServer.set_bus_mute(bus, linear_value < 0.01)


func fade_out_music(duration: float = 1.0) -> void:
	var bus_idx := Bus.MUSIC
	var current := db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_bus_volume_linear.bind(bus_idx), current, 0.0, duration)


func _set_bus_volume_linear(value: float, bus: Bus) -> void:
	var db := linear_to_db(value)
	AudioServer.set_bus_volume_db(bus, db)
	if value < 0.01:
		AudioServer.set_bus_mute(bus, true)


func _on_music_volume_changed(value: float) -> void:
	set_bus_volume(Bus.MUSIC, value * Settings.overall_volume)


func _on_effects_volume_changed(value: float) -> void:
	set_bus_volume(Bus.EFFECTS, value * Settings.overall_volume)


func _on_overall_volume_changed(value: float) -> void:
	set_bus_volume(Bus.MUSIC, Settings.music_volume * value)
	set_bus_volume(Bus.EFFECTS, Settings.effects_volume * value)


func _on_music_finished() -> void:
	if _music_player != null:
		_music_player.play()


func _bus_name(bus: Bus) -> String:
	match bus:
		Bus.MASTER:
			return "Master"
		Bus.MUSIC:
			return "Music"
		Bus.EFFECTS:
			return "Effects"
	return "Master"
