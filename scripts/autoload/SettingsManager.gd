class_name SettingsManager
extends Node

const SAVE_PATH := "user://settings.cfg"

signal music_volume_changed(value: float)
signal effects_volume_changed(value: float)
signal overall_volume_changed(value: float)
signal fps_changed(value: int)
signal theme_changed(dark_mode: bool)

# Suppresses disk writes while properties are being populated in bulk
# (load_settings / reset_to_defaults), so a single save() runs at the end.
var _loading := false

var music_volume: float = 0.8:
	set(value):
		music_volume = clamp(value, 0.0, 1.0)
		music_volume_changed.emit(music_volume)
		_save_unless_loading()

var effects_volume: float = 0.8:
	set(value):
		effects_volume = clamp(value, 0.0, 1.0)
		effects_volume_changed.emit(effects_volume)
		_save_unless_loading()

var overall_volume: float = 1.0:
	set(value):
		overall_volume = clamp(value, 0.0, 1.0)
		overall_volume_changed.emit(overall_volume)
		_save_unless_loading()

var target_fps: int = 60:
	set(value):
		target_fps = value
		Engine.max_fps = target_fps
		fps_changed.emit(target_fps)
		_save_unless_loading()

var dark_mode: bool = true:
	set(value):
		dark_mode = value
		theme_changed.emit(dark_mode)
		_save_unless_loading()


func _ready() -> void:
	load_settings()
	Engine.max_fps = target_fps


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		return

	_loading = true
	music_volume = cfg.get_value("audio", "music_volume", 0.8)
	effects_volume = cfg.get_value("audio", "effects_volume", 0.8)
	overall_volume = cfg.get_value("audio", "overall_volume", 1.0)
	target_fps = cfg.get_value("video", "target_fps", 60)
	dark_mode = cfg.get_value("video", "dark_mode", true)
	_loading = false


func _save_unless_loading() -> void:
	if not _loading:
		save()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "effects_volume", effects_volume)
	cfg.set_value("audio", "overall_volume", overall_volume)
	cfg.set_value("video", "target_fps", target_fps)
	cfg.set_value("video", "dark_mode", dark_mode)
	cfg.save(SAVE_PATH)


func reset_to_defaults() -> void:
	_loading = true
	music_volume = 0.8
	effects_volume = 0.8
	overall_volume = 1.0
	target_fps = 60
	dark_mode = true
	_loading = false
	save()
