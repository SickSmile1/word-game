class_name Trie
extends RefCounted

const TrieNode = preload("res://scripts/game/TrieNode.gd")

var root: TrieNode


func _init():
	root = TrieNode.new()


func insert(word: String) -> void:
	var node = root
	for c in word:
		if not node.children.has(c):
			node.children[c] = TrieNode.new()
		node = node.children[c]
	node.is_end = true


func search(word: String) -> bool:
	var node = _traverse(word)
	return node != null and node.is_end


func starts_with(prefix: String) -> bool:
	var node = _traverse(prefix)
	return node != null


func get_node(prefix: String) -> TrieNode:
	return _traverse(prefix)


func count_words() -> int:
	return _count_from(root)


func _count_from(node: TrieNode) -> int:
	var count := 0
	if node.is_end:
		count += 1
	for child in node.children.values():
		count += _count_from(child)
	return count


func _traverse(s: String) -> TrieNode:
	var node = root
	for c in s:
		if not node.children.has(c):
			return null
		node = node.children[c]
	return node
