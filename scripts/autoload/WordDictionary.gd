class_name WordDictionaryManager
extends Node

## Loads the German Scrabble word list into a Trie once at startup.
## Shared by move validation ([method is_valid_word]) and the AI ([member trie]).

signal dictionary_ready

const Trie = preload("res://scripts/game/Trie.gd")
const WORDLIST_PATH := "res://assets/dictionary/german_scrabble.txt"

var trie: Trie
var is_ready := false
var word_count := 0

const MAX_CHUNK_MS := 15

var _chunk_file: FileAccess


func _ready() -> void:
	trie = Trie.new()
	if OS.has_feature("web"):
		_load_chunked()
	else:
		var thread := Thread.new()
		thread.start(_load_on_thread.bind(thread))


func _load_on_thread(thread: Thread) -> void:
	var file := FileAccess.open(WORDLIST_PATH, FileAccess.READ)
	if file:
		while not file.eof_reached():
			var word := file.get_line().strip_edges().to_upper()
			if word.length() >= 2:
				trie.insert(word)
				word_count += 1
		file.close()
	else:
		push_error("WordDictionary: could not open " + WORDLIST_PATH)
		trie = null
	call_deferred("_finish_load", thread)


func _finish_load(thread: Thread = null) -> void:
	if thread:
		thread.wait_to_finish()
	is_ready = true
	dictionary_ready.emit()


# The single-threaded web export cannot run Threads, so load the word list on
# the main thread in small time-sliced chunks to keep the UI responsive.
func _load_chunked() -> void:
	_chunk_file = FileAccess.open(WORDLIST_PATH, FileAccess.READ)
	if not _chunk_file:
		push_error("WordDictionary: could not open " + WORDLIST_PATH)
		trie = null
		_finish_load()
		return
	await _read_chunk()


func _read_chunk() -> void:
	var start := Time.get_ticks_msec()
	var lines_in_chunk := 0
	while not _chunk_file.eof_reached():
		var word := _chunk_file.get_line().strip_edges().to_upper()
		if word.length() >= 2:
			trie.insert(word)
			word_count += 1
		lines_in_chunk += 1
		if lines_in_chunk % 500 == 0:
			if Time.get_ticks_msec() - start > MAX_CHUNK_MS:
				break
	if _chunk_file.eof_reached():
		_chunk_file.close()
		_finish_load()
	else:
		await get_tree().process_frame
		await _read_chunk()


func is_valid_word(word: String) -> bool:
	return trie != null and trie.search(word.to_upper())
