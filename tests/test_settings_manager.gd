extends GutTest

var _settings: SettingsManager


func before_each() -> void:
	_settings = autofree(SettingsManager.new())


func test_default_music_volume() -> void:
	assert_eq(_settings.music_volume, 0.8)


func test_default_effects_volume() -> void:
	assert_eq(_settings.effects_volume, 0.8)


func test_default_overall_volume() -> void:
	assert_eq(_settings.overall_volume, 1.0)


func test_default_target_fps() -> void:
	assert_eq(_settings.target_fps, 60)


func test_music_volume_clamped() -> void:
	_settings.music_volume = 1.5
	assert_eq(_settings.music_volume, 1.0)
	_settings.music_volume = -0.5
	assert_eq(_settings.music_volume, 0.0)


func test_effects_volume_clamped() -> void:
	_settings.effects_volume = 1.5
	assert_eq(_settings.effects_volume, 1.0)
	_settings.effects_volume = -0.5
	assert_eq(_settings.effects_volume, 0.0)


func test_overall_volume_clamped() -> void:
	_settings.overall_volume = 1.5
	assert_eq(_settings.overall_volume, 1.0)
	_settings.overall_volume = -0.5
	assert_eq(_settings.overall_volume, 0.0)


func test_music_volume_emits_signal() -> void:
	watch_signals(_settings)
	_settings.music_volume = 0.5
	assert_signal_emitted(_settings, "music_volume_changed")


func test_effects_volume_emits_signal() -> void:
	watch_signals(_settings)
	_settings.effects_volume = 0.5
	assert_signal_emitted(_settings, "effects_volume_changed")


func test_overall_volume_emits_signal() -> void:
	watch_signals(_settings)
	_settings.overall_volume = 0.5
	assert_signal_emitted(_settings, "overall_volume_changed")


func test_fps_emits_signal() -> void:
	watch_signals(_settings)
	_settings.target_fps = 30
	assert_signal_emitted(_settings, "fps_changed")


func test_fps_sets_engine_max_fps() -> void:
	_settings.target_fps = 30
	assert_eq(Engine.max_fps, 30)


func test_reset_to_defaults() -> void:
	_settings.music_volume = 0.2
	_settings.effects_volume = 0.3
	_settings.overall_volume = 0.5
	_settings.target_fps = 30
	_settings.reset_to_defaults()
	assert_eq(_settings.music_volume, 0.8)
	assert_eq(_settings.effects_volume, 0.8)
	assert_eq(_settings.overall_volume, 1.0)
	assert_eq(_settings.target_fps, 60)


func test_save_and_load_roundtrip() -> void:
	_settings.music_volume = 0.3
	_settings.effects_volume = 0.4
	_settings.overall_volume = 0.9
	_settings.target_fps = 30
	_settings.save()

	var loaded = autofree(SettingsManager.new())
	loaded.load_settings()
	assert_eq(loaded.music_volume, 0.3)
	assert_eq(loaded.effects_volume, 0.4)
	assert_eq(loaded.overall_volume, 0.9)
	assert_eq(loaded.target_fps, 30)

	_settings.reset_to_defaults()
	_settings.save()


func test_load_settings_applies_values_and_emits_signals() -> void:
	_settings.music_volume = 0.3
	_settings.effects_volume = 0.4
	_settings.dark_mode = false
	_settings.save()

	var loaded = autofree(SettingsManager.new())
	watch_signals(loaded)
	loaded.load_settings()

	assert_eq(loaded.music_volume, 0.3)
	assert_eq(loaded.effects_volume, 0.4)
	assert_eq(loaded.dark_mode, false)
	# Signals must still fire on load so dependent systems (audio buses) update.
	assert_signal_emitted(loaded, "music_volume_changed")
	assert_signal_emitted(loaded, "theme_changed")

	_settings.reset_to_defaults()
	_settings.save()


func test_loading_guard_resets_after_load() -> void:
	# The guard that suppresses redundant disk writes during bulk loads must
	# never leave the manager stuck in the loading state.
	_settings.save()
	_settings.load_settings()
	assert_false(_settings._loading)

	_settings.reset_to_defaults()
	assert_false(_settings._loading)
