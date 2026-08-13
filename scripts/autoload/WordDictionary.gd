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
		var text := file.get_as_text()
		file.close()
		var lines := text.split("\n")
		for l in lines:
			var word := l.strip_edges().to_upper()
			if word.length() >= 2:
				trie.insert(word)
				word_count += 1
	else:
		push_error("WordDictionary: could not open " + WORDLIST_PATH)
		trie = null
	call_deferred("_finish_load", thread)


func _finish_load(thread: Thread = null) -> void:
	if thread:
		thread.wait_to_finish()
	is_ready = true
	print("[WordDict] Loaded %d words into dictionary trie" % word_count)
	dictionary_ready.emit()


# The single-threaded web export cannot run Threads, so load the word list on
# the main thread using fast bulk text splitting and time-sliced batch chunks.
func _load_chunked() -> void:
	var file := FileAccess.open(WORDLIST_PATH, FileAccess.READ)
	if not file:
		push_error("WordDictionary: could not open " + WORDLIST_PATH)
		trie = null
		_finish_load()
		return

	var text := file.get_as_text()
	file.close()

	var lines := text.split("\n")
	var total := lines.size()
	var idx := 0

	while idx < total:
		var start := Time.get_ticks_msec()
		var end_idx := min(idx + 5000, total)
		for i in range(idx, end_idx):
			var word := lines[i].strip_edges().to_upper()
			if word.length() >= 2:
				trie.insert(word)
				word_count += 1
		idx = end_idx
		if idx < total and Time.get_ticks_msec() - start > MAX_CHUNK_MS:
			await get_tree().process_frame

	_finish_load()


func is_valid_word(word: String) -> bool:
	return trie != null and trie.search(word.to_upper())
