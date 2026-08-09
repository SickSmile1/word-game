class_name MainMenu
extends Control

enum MenuState { MAIN, START, SETTINGS, CONTINUE }

@onready var background: ColorRect = %Background
@onready var title_label: Label = %TitleLabel
@onready var menu_container: VBoxContainer = %MenuContainer
@onready var start_button: Button = %StartButton
@onready var online_button: Button = %OnlineButton
@onready var vs_ai_button: Button = %VsAiButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

@onready var start_panel: Panel = %StartPanel
@onready var back_start_button: Button = %BackStartButton

@onready var settings_panel: Panel = %SettingsPanel
@onready var settings_container: VBoxContainer = %SettingsContainer
@onready var close_settings_button: Button = %CloseSettingsButton

@onready var music_slider: HSlider = %MusicSlider
@onready var effects_slider: HSlider = %EffectsSlider
@onready var overall_slider: HSlider = %OverallSlider
@onready var fps_30_button: Button = %Fps30Button
@onready var fps_60_button: Button = %Fps60Button
@onready var dark_button: Button = %DarkButton
@onready var light_button: Button = %LightButton

@onready var music_value_label: Label = %MusicValue
@onready var effects_value_label: Label = %EffectsValue
@onready var overall_value_label: Label = %OverallValue

@onready var continue_panel: Panel = %ContinuePanel
@onready var slot_list: VBoxContainer = %SlotList
@onready var no_saves_label: Label = %NoSavesLabel
@onready var back_continue_button: Button = %BackContinueButton

var _state: MenuState = MenuState.MAIN:
	set(value):
		_state = value
		_update_ui_state()


func _ready() -> void:
	_setup_buttons()
	_setup_sliders()
	_setup_fps_buttons()
	_setup_theme_buttons()
	_populate_slider_values()
	_populate_fps_value()
	_populate_theme_value()
	_apply_background(Settings.dark_mode)
	Settings.theme_changed.connect(_on_theme_changed)
	_update_ui_state()
	_populate_slot_list()


func _setup_buttons() -> void:
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	close_settings_button.pressed.connect(_on_close_settings_pressed)
	online_button.pressed.connect(_on_online_pressed)
	vs_ai_button.pressed.connect(_on_vs_ai_pressed)
	back_start_button.pressed.connect(_on_back_start_pressed)
	back_continue_button.pressed.connect(_on_back_continue_pressed)


func _setup_sliders() -> void:
	music_slider.value_changed.connect(_on_music_slider_changed)
	effects_slider.value_changed.connect(_on_effects_slider_changed)
	overall_slider.value_changed.connect(_on_overall_slider_changed)


func _setup_fps_buttons() -> void:
	fps_30_button.pressed.connect(_on_fps_30_pressed)
	fps_60_button.pressed.connect(_on_fps_60_pressed)


func _setup_theme_buttons() -> void:
	dark_button.pressed.connect(_on_dark_pressed)
	light_button.pressed.connect(_on_light_pressed)


func _populate_slider_values() -> void:
	music_slider.value = Settings.music_volume
	effects_slider.value = Settings.effects_volume
	overall_slider.value = Settings.overall_volume
	music_value_label.text = "%d" % (Settings.music_volume * 100)
	effects_value_label.text = "%d" % (Settings.effects_volume * 100)
	overall_value_label.text = "%d" % (Settings.overall_volume * 100)


func _populate_fps_value() -> void:
	_update_fps_buttons(Settings.target_fps)


func _populate_theme_value() -> void:
	_update_theme_buttons(Settings.dark_mode)


func _update_ui_state() -> void:
	start_panel.visible = _state == MenuState.START
	settings_panel.visible = _state == MenuState.SETTINGS
	continue_panel.visible = _state == MenuState.CONTINUE
	menu_container.visible = _state == MenuState.MAIN


func _update_fps_buttons(fps: int) -> void:
	fps_30_button.button_pressed = fps == 30
	fps_60_button.button_pressed = fps == 60


func _update_theme_buttons(dark: bool) -> void:
	dark_button.button_pressed = dark
	light_button.button_pressed = not dark


func _apply_background(dark: bool) -> void:
	background.color = Color(0.08, 0.08, 0.15, 1) if dark else Color(0.93, 0.90, 0.83, 1)
	_style_menu_theme(dark)


func _populate_slot_list() -> void:
	for c in slot_list.get_children():
		c.queue_free()

	var saves = SaveManager.get_save_list()
	if saves.is_empty():
		no_saves_label.visible = true
		slot_list.visible = false
		return

	no_saves_label.visible = false
	slot_list.visible = true

	for save in saves:
		var btn = Button.new()
		var diff = save.get("difficulty", "Unknown")
		var ts = save.get("timestamp", "")
		var hs = save.get("human_score", 0)
		var ais = save.get("ai_score", 0)
		var date = ""
		if not ts.is_empty():
			var parts = ts.split("T")
			date = parts[0] if parts.size() > 0 else ts
			if parts.size() > 1:
				date += " " + parts[1].left(5)

		btn.text = "%s — %s\nYou: %d  AI: %d" % [diff, date, hs, ais]
		btn.custom_minimum_size = Vector2(552, 92)
		var style = _make_slot_style()
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override(
			"font_color", Color(1, 1, 1, 1) if Settings.dark_mode else Color(0.08, 0.06, 0.12, 1)
		)
		btn.add_theme_color_override("font_hover_color", Color(0.91, 0.27, 0.38, 1))
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var slot_num = save.get("slot", 0)
		btn.pressed.connect(func(): _on_slot_selected(slot_num))
		slot_list.add_child(btn)


func _make_slot_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = (
		Color(0.13, 0.13, 0.24, 1) if Settings.dark_mode else Color(0.88, 0.84, 0.78, 1)
	)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.91, 0.27, 0.38, 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style


func _on_start_pressed() -> void:
	_state = MenuState.START


func _on_back_start_pressed() -> void:
	_state = MenuState.MAIN


func _on_online_pressed() -> void:
	_state = MenuState.MAIN
	get_tree().change_scene_to_file("res://scenes/lobby/Lobby.tscn")


func _on_vs_ai_pressed() -> void:
	_state = MenuState.MAIN
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")


func _on_continue_pressed() -> void:
	_populate_slot_list()
	_state = MenuState.CONTINUE


func _on_back_continue_pressed() -> void:
	_state = MenuState.MAIN


func _on_slot_selected(slot: int) -> void:
	SaveManager.pending_load_slot = slot
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")


func _on_settings_pressed() -> void:
	_state = MenuState.SETTINGS


func _on_close_settings_pressed() -> void:
	_state = MenuState.MAIN


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_music_slider_changed(value: float) -> void:
	Settings.music_volume = value
	music_value_label.text = "%d" % (value * 100)


func _on_effects_slider_changed(value: float) -> void:
	Settings.effects_volume = value
	effects_value_label.text = "%d" % (value * 100)


func _on_overall_slider_changed(value: float) -> void:
	Settings.overall_volume = value
	overall_value_label.text = "%d" % (value * 100)


func _on_fps_30_pressed() -> void:
	Settings.target_fps = 30
	_update_fps_buttons(30)


func _on_fps_60_pressed() -> void:
	Settings.target_fps = 60
	_update_fps_buttons(60)


func _on_theme_changed(dark: bool) -> void:
	_apply_background(dark)
	if %ContinuePanel.visible:
		_populate_slot_list()


func _on_dark_pressed() -> void:
	Settings.dark_mode = true
	_update_theme_buttons(true)


func _on_light_pressed() -> void:
	Settings.dark_mode = false
	_update_theme_buttons(false)


func _style_menu_theme(dark: bool) -> void:
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
	var body_font: Color = Color(0.85, 0.85, 0.92, 1) if dark else Color(0.35, 0.38, 0.44, 1)
	var accent_font: Color = Color(0.91, 0.27, 0.38, 1)
	var muted_font: Color = Color(0.75, 0.75, 0.85, 1) if dark else Color(0.50, 0.50, 0.60, 1)
	var toggle_font: Color = Color(0.70, 0.70, 0.82, 1) if dark else Color(0.40, 0.40, 0.52, 1)

	for b in [
		%StartButton,
		%ContinueButton,
		%SettingsButton,
		%QuitButton,
		%OnlineButton,
		%VsAiButton,
		%BackStartButton
	]:
		b.add_theme_stylebox_override("normal", btn_style)
		b.add_theme_stylebox_override("hover", btn_style)
		b.add_theme_stylebox_override("pressed", btn_style)
		b.add_theme_color_override("font_color", btn_font)
		b.add_theme_color_override("font_hover_color", btn_hover)

	%CloseSettingsButton.add_theme_stylebox_override("normal", btn_style)
	%CloseSettingsButton.add_theme_stylebox_override("hover", btn_style)
	%CloseSettingsButton.add_theme_stylebox_override("pressed", btn_style)
	%CloseSettingsButton.add_theme_color_override("font_color", btn_font)
	%CloseSettingsButton.add_theme_color_override("font_hover_color", btn_hover)

	%BackContinueButton.add_theme_stylebox_override("normal", btn_style)
	%BackContinueButton.add_theme_stylebox_override("hover", btn_style)
	%BackContinueButton.add_theme_stylebox_override("pressed", btn_style)
	%BackContinueButton.add_theme_color_override("font_color", btn_font)
	%BackContinueButton.add_theme_color_override("font_hover_color", btn_hover)

	%StartPanel.add_theme_stylebox_override("panel", panel_style)
	%SettingsPanel.add_theme_stylebox_override("panel", panel_style)
	%ContinuePanel.add_theme_stylebox_override("panel", panel_style)

	%TitleLabel.add_theme_color_override("font_color", accent_font)

	for tb in [%Fps30Button, %Fps60Button, %DarkButton, %LightButton]:
		tb.add_theme_stylebox_override("normal", btn_style)
		tb.add_theme_stylebox_override("hover", btn_style)
		tb.add_theme_stylebox_override("pressed", btn_style)
		tb.add_theme_color_override("font_color", toggle_font)
		tb.add_theme_color_override("font_hover_color", btn_hover)

	for sl in [
		%StartPanel.get_node("MarginContainer/StartContainer/StartTitle"),
		%SettingsPanel.get_node("MarginContainer/SettingsContainer/SettingsTitle"),
		%ContinuePanel.get_node("MarginContainer/ContinueVBox/ContinueTitle"),
	]:
		sl.add_theme_color_override("font_color", accent_font)

	var settings_root := %SettingsPanel.get_node("MarginContainer/SettingsContainer")
	var section_paths := [
		"VolumeSection/VolumeLabel",
		"FpsSection/FpsLabel",
		"ThemeSection/ThemeLabel",
	]
	for sp in section_paths:
		var found := settings_root.get_node_or_null(sp)
		if found:
			found.add_theme_color_override("font_color", body_font)

	var row_paths := [
		"VolumeSection/MusicRow/MusicLabel",
		"VolumeSection/EffectsRow/EffectsLabel",
		"VolumeSection/OverallRow/OverallLabel",
	]
	for rp in row_paths:
		var found := settings_root.get_node_or_null(rp)
		if found:
			found.add_theme_color_override(
				"font_color", Color(1, 1, 1, 1) if dark else Color(0.08, 0.06, 0.12, 1)
			)

	for vl in [%MusicValue, %EffectsValue, %OverallValue]:
		vl.add_theme_color_override("font_color", muted_font)

	%NoSavesLabel.add_theme_color_override("font_color", muted_font)


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
