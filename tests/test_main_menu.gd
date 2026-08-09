extends GutTest

var _menu: Control


func before_each() -> void:
	_menu = autofree(load("res://scenes/main_menu/MainMenu.tscn").instantiate())
	add_child_auto(_menu)


func test_initial_state_is_main() -> void:
	assert_eq(_menu._state, _menu.MenuState.MAIN)


func test_start_button_shows_start_panel() -> void:
	_menu._on_start_pressed()
	assert_eq(_menu._state, _menu.MenuState.START)


func test_start_panel_visible_in_start_state() -> void:
	_menu._on_start_pressed()
	assert_true(_menu.start_panel.visible)
	assert_false(_menu.settings_panel.visible)
	assert_false(_menu.menu_container.visible)


func test_settings_button_shows_settings_panel() -> void:
	_menu._on_settings_pressed()
	assert_eq(_menu._state, _menu.MenuState.SETTINGS)
	assert_true(_menu.settings_panel.visible)
	assert_false(_menu.menu_container.visible)


func test_close_settings_returns_to_main() -> void:
	_menu._on_settings_pressed()
	_menu._on_close_settings_pressed()
	assert_eq(_menu._state, _menu.MenuState.MAIN)


func test_back_start_returns_to_main() -> void:
	_menu._on_start_pressed()
	_menu._on_back_start_pressed()
	assert_eq(_menu._state, _menu.MenuState.MAIN)


func test_quit_calls_tree_quit() -> void:
	assert_has_signal(_menu.get_tree(), "tree_exiting")


func test_music_slider_updates_label() -> void:
	_menu._on_music_slider_changed(0.5)
	assert_eq(_menu.music_value_label.text, "50")


func test_effects_slider_updates_label() -> void:
	_menu._on_effects_slider_changed(0.75)
	assert_eq(_menu.effects_value_label.text, "75")


func test_overall_slider_updates_label() -> void:
	_menu._on_overall_slider_changed(1.0)
	assert_eq(_menu.overall_value_label.text, "100")


func test_fps_30_button_toggle() -> void:
	_menu._on_fps_30_pressed()
	assert_true(_menu.fps_30_button.button_pressed)
	assert_false(_menu.fps_60_button.button_pressed)


func test_fps_60_button_toggle() -> void:
	_menu._on_fps_30_pressed()
	_menu._on_fps_60_pressed()
	assert_false(_menu.fps_30_button.button_pressed)
	assert_true(_menu.fps_60_button.button_pressed)


func test_state_update_hides_everything_in_main() -> void:
	_menu._on_start_pressed()
	_menu._on_back_start_pressed()
	assert_false(_menu.start_panel.visible)
	assert_false(_menu.settings_panel.visible)
	assert_true(_menu.menu_container.visible)
