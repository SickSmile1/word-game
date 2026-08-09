class_name GameOverOverlay
extends Control

signal play_again_pressed
signal main_menu_pressed


func _ready():
	visible = false


func show_scores(
	human_score: int, ai_score: int, human_name: String = "You", ai_name: String = "AI"
):
	visible = true

	var title_label = %GameOverTitle as Label
	var scores_label = %FinalScores as Label
	var winner_label = %WinnerLabel as Label

	scores_label.text = "%s: %d\n%s: %d" % [human_name, human_score, ai_name, ai_score]

	if human_score > ai_score:
		winner_label.text = "%s wins!" % human_name
		winner_label.add_theme_color_override("font_color", Color(0.24, 0.67, 0.36, 1))
	elif ai_score > human_score:
		winner_label.text = "%s wins!" % ai_name
		winner_label.add_theme_color_override("font_color", Color(0.91, 0.27, 0.38, 1))
	else:
		winner_label.text = "It's a tie!"
		winner_label.add_theme_color_override("font_color", Color(0.75, 0.70, 0.30, 1))


func _on_play_again():
	play_again_pressed.emit()


func _on_main_menu():
	main_menu_pressed.emit()
