class_name Lobby
extends Control

@onready var background: ColorRect = %Background
@onready var panel: Panel = %Panel
@onready var title: Label = %Title
@onready var create_button: Button = %CreateButton
@onready var join_button: Button = %JoinButton
@onready var room_panel: VBoxContainer = %RoomPanel
@onready var room_label: Label = %RoomLabel
@onready var code_input: LineEdit = %CodeInput
@onready var status_label: Label = %StatusLabel
@onready var back_button: Button = %BackButton
@onready var privacy_note: Label = %PrivacyNote


func _ready() -> void:
	_apply_background(Settings.dark_mode)
	Settings.theme_changed.connect(_on_theme_changed)
	create_button.pressed.connect(_on_create_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	code_input.text_submitted.connect(func(_t): _on_code_submitted())
	Net.session_started.connect(_on_session_started)
	Net.peer_connected.connect(_on_peer_connected)
	Net.net_error.connect(_on_net_error)
	Net.host_connected.connect(_on_host_connected)


func _on_create_pressed() -> void:
	create_button.disabled = true
	join_button.disabled = true
	room_panel.visible = true
	code_input.visible = false
	room_label.text = "Waiting for opponent…"
	status_label.text = ""
	Net.start_host("")


func _on_join_pressed() -> void:
	create_button.disabled = true
	join_button.disabled = true
	room_panel.visible = true
	code_input.visible = true
	code_input.grab_focus()
	status_label.text = ""


func _on_code_submitted() -> void:
	var code := code_input.text.strip_edges()
	if code.is_empty():
		status_label.text = "Enter a room code"
		return
	code_input.editable = false
	status_label.text = "Joining…"
	Net.start_guest(code)


func _on_host_connected(code: String, _slot: int) -> void:
	room_label.text = code
	status_label.text = "Waiting for opponent…"


func _on_session_started(_host: bool) -> void:
	pass


func _on_peer_connected() -> void:
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")


func _on_net_error(reason: String) -> void:
	status_label.text = reason
	create_button.disabled = false
	join_button.disabled = false
	code_input.editable = true


func _on_back_pressed() -> void:
	Net.teardown()
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")


func _exit_tree() -> void:
	Net.teardown()


func _on_theme_changed(dark: bool) -> void:
	_apply_background(dark)


func _apply_background(dark: bool) -> void:
	background.color = Color(0.08, 0.08, 0.15, 1) if dark else Color(0.93, 0.90, 0.83, 1)
	_style_lobby_theme(dark)


func _style_lobby_theme(dark: bool) -> void:
	var btn_style := _make_menu_style(
		Color(0.13, 0.13, 0.24, 1) if dark else Color(0.88, 0.84, 0.78, 1),
		Color(0.91, 0.27, 0.38, 1),
		10
	)
	var panel_style := _make_menu_style(
		Color(0.11, 0.11, 0.20, 0.95) if dark else Color(0.98, 0.97, 0.95, 0.95),
		Color(0.91, 0.27, 0.38, 1),
		16
	)

	var btn_font: Color = Color(1, 1, 1, 1) if dark else Color(0.08, 0.06, 0.12, 1)
	var btn_hover: Color = Color(0.91, 0.27, 0.38, 1)
	var accent_font: Color = Color(0.91, 0.27, 0.38, 1)
	var muted_font: Color = Color(0.75, 0.75, 0.85, 1) if dark else Color(0.50, 0.50, 0.60, 1)
	var body_font: Color = Color(1, 1, 1, 1) if dark else Color(0.08, 0.06, 0.12, 1)

	for b in [create_button, join_button, back_button]:
		b.add_theme_stylebox_override("normal", btn_style)
		b.add_theme_stylebox_override("hover", btn_style)
		b.add_theme_stylebox_override("pressed", btn_style)
		b.add_theme_color_override("font_color", btn_font)
		b.add_theme_color_override("font_hover_color", btn_hover)

	panel.add_theme_stylebox_override("panel", panel_style)
	title.add_theme_color_override("font_color", accent_font)
	room_label.add_theme_color_override("font_color", body_font)
	code_input.add_theme_color_override("font_color", body_font)
	code_input.add_theme_color_override("font_placeholder_color", muted_font)
	status_label.add_theme_color_override("font_color", body_font)
	privacy_note.add_theme_color_override("font_color", muted_font)


func _make_menu_style(bg: Color, border: Color, radius: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.border_color = border
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_right = radius
	s.corner_radius_bottom_left = radius
	return s
