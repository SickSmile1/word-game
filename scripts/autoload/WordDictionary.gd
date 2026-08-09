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


func _ready() -> void:
	trie = Trie.new()
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


func _finish_load(thread: Thread) -> void:
	thread.wait_to_finish()
	is_ready = true
	dictionary_ready.emit()


func is_valid_word(word: String) -> bool:
	return trie != null and trie.search(word.to_upper())
