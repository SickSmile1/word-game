extends GutTest

var _audio: AudioManager


func before_each() -> void:
	_audio = autofree(AudioManager.new())
	add_child_auto(_audio)


func test_initial_bus_count() -> void:
	assert_gt(AudioServer.bus_count, 2)


func test_bus_name_master() -> void:
	assert_eq(_audio._bus_name(_audio.Bus.MASTER), "Master")


func test_bus_name_music() -> void:
	assert_eq(_audio._bus_name(_audio.Bus.MUSIC), "Music")


func test_bus_name_effects() -> void:
	assert_eq(_audio._bus_name(_audio.Bus.EFFECTS), "Effects")


func test_bus_name_fallback() -> void:
	assert_eq(_audio._bus_name(99), "Master")


func test_set_bus_volume_linear_zero() -> void:
	_audio.set_bus_volume(_audio.Bus.MUSIC, 0.0)
	assert_true(AudioServer.is_bus_mute(_audio.Bus.MUSIC))


func test_set_bus_volume_linear_full() -> void:
	_audio.set_bus_volume(_audio.Bus.MUSIC, 1.0)
	assert_false(AudioServer.is_bus_mute(_audio.Bus.MUSIC))
	assert_gt(AudioServer.get_bus_volume_db(_audio.Bus.MUSIC), -80.0)


func _count_music_players() -> int:
	var count := 0
	for child in _audio.get_children():
		if child is AudioStreamPlayer2D:
			count += 1
	return count


func test_play_music_reuses_single_player() -> void:
	var stream := AudioStreamWAV.new()

	_audio.play_music(stream)
	_audio.play_music(stream)
	_audio.play_music(stream)

	assert_eq(_count_music_players(), 1, "play_music must not accumulate players")
	assert_not_null(_audio._music_player)


func test_play_music_no_loop_disconnects_finished() -> void:
	var stream := AudioStreamWAV.new()

	_audio.play_music(stream, true)
	assert_true(_audio._music_player.finished.is_connected(_audio._on_music_finished))

	_audio.play_music(stream, false)
	assert_false(_audio._music_player.finished.is_connected(_audio._on_music_finished))
