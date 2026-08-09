class_name TrieNode
extends RefCounted

var children: Dictionary
var is_end: bool


func _init():
	children = {}
	is_end = false
