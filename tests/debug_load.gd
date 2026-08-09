extends Node


func _init() -> void:
	var mg_path = "res://scripts/ai/MoveGenerator.gd"
	var MoveGenerator = load(mg_path)
	if MoveGenerator:
		print("Loaded: ", MoveGenerator)
		var mg = MoveGenerator.new()
		if mg:
			print("Instantiated OK")
			print("generate_moves: ", mg.has_method("generate_moves"))
		else:
			print("Failed to instantiate")
	else:
		print("Failed to load: ", mg_path)

	var ai_path = "res://scripts/ai/AIPlayer.gd"
	var AIPlayer = load(ai_path)
	if AIPlayer:
		print("AIPlayer loaded: ", AIPlayer)
		var ai = AIPlayer.new()
		if ai:
			print("AIPlayer instantiated OK")
		else:
			print("AIPlayer failed to instantiate")

	get_tree().quit()
