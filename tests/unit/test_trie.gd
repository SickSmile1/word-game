extends GutTest

const Trie = preload("res://scripts/game/Trie.gd")

var _trie


func before_each() -> void:
	_trie = autofree(Trie.new())


func test_empty_trie_search_returns_false() -> void:
	assert_false(_trie.search("HELLO"))


func test_empty_trie_starts_with_returns_false() -> void:
	assert_false(_trie.starts_with("HE"))


func test_insert_and_search_word() -> void:
	_trie.insert("CAT")
	assert_true(_trie.search("CAT"))


func test_search_nonexistent_word() -> void:
	_trie.insert("CAT")
	assert_false(_trie.search("DOG"))


func test_starts_with_existing_prefix() -> void:
	_trie.insert("CAT")
	_trie.insert("CAR")
	assert_true(_trie.starts_with("CA"))


func test_starts_with_nonexistent_prefix() -> void:
	_trie.insert("CAT")
	assert_false(_trie.starts_with("DO"))


func test_word_is_not_prefix_of_another_word() -> void:
	_trie.insert("CAT")
	_trie.insert("CATS")
	assert_true(_trie.search("CAT"))
	assert_true(_trie.search("CATS"))


func test_multiple_words() -> void:
	_trie.insert("HELLO")
	_trie.insert("HELP")
	_trie.insert("HELPER")
	assert_true(_trie.search("HELLO"))
	assert_true(_trie.search("HELP"))
	assert_true(_trie.search("HELPER"))
	assert_false(_trie.search("HEL"))


func test_starts_with_exact_word_is_also_prefix() -> void:
	_trie.insert("HELLO")
	assert_true(_trie.starts_with("HELLO"))


func test_get_node_returns_valid_node() -> void:
	_trie.insert("TEST")
	var node = _trie.get_node("TE")
	assert_not_null(node)
	assert_false(node.is_end)

	var full_node = _trie.get_node("TEST")
	assert_not_null(full_node)
	assert_true(full_node.is_end)


func test_get_node_nonexistent_returns_null() -> void:
	_trie.insert("TEST")
	var node = _trie.get_node("XYZ")
	assert_null(node)
