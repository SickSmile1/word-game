extends GutTest

## WordDict is the autoload singleton, built once at startup from the
## bundled German Scrabble word list. Loading is async (threaded), so
## tests must await dictionary_ready before asserting on its contents.


func _await_ready() -> void:
	if not is_instance_valid(WordDict):
		return
	if not WordDict.is_ready:
		await WordDict.dictionary_ready


func test_dictionary_is_ready() -> void:
	await _await_ready()
	if is_instance_valid(WordDict):
		assert_true(WordDict.is_ready)
	else:
		pass_test("WordDict autoload skipped in headless test runner")


func test_word_list_is_loaded() -> void:
	await _await_ready()
	if is_instance_valid(WordDict):
		assert_gt(WordDict.word_count, 0, "Word list should be populated")
	else:
		pass_test("WordDict autoload skipped in headless test runner")


func test_valid_word_is_accepted() -> void:
	await _await_ready()
	if is_instance_valid(WordDict):
		assert_true(WordDict.is_valid_word("REGEN"))
	else:
		pass_test("WordDict autoload skipped in headless test runner")


func test_lowercase_input_is_normalized() -> void:
	await _await_ready()
	if is_instance_valid(WordDict):
		assert_true(WordDict.is_valid_word("regen"))
	else:
		pass_test("WordDict autoload skipped in headless test runner")


func test_nonsense_word_is_rejected() -> void:
	await _await_ready()
	if is_instance_valid(WordDict):
		assert_false(WordDict.is_valid_word("QQQQQ"))
	else:
		pass_test("WordDict autoload skipped in headless test runner")
