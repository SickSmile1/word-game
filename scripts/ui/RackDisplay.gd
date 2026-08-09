class_name RackDisplay
extends HBoxContainer

signal tile_selected(index: int)
signal tile_deselected
signal placed_tile_clicked(index: int)

const Tiles = preload("res://scripts/game/Tiles.gd")

const SLOT_SIZE := 80
const SLOT_GAP := 6
const SELECTED_BORDER_COLOR := Color(0.91, 0.27, 0.38, 1)
const EXCHANGE_BORDER_COLOR := Color(0.16, 0.60, 0.85, 1)

var _tile_color: Color = Color(0.95, 0.92, 0.78, 1)
var _empty_color: Color = Color(0.15, 0.15, 0.25, 0.5)
var _placed_color: Color = Color(0.38, 0.38, 0.38, 0.7)
var _letter_color: Color = Color(0.10, 0.08, 0.06, 1)
var _placed_letter_color: Color = Color(0.12, 0.10, 0.08, 1)
var _value_color: Color = Color(0.30, 0.25, 0.18, 1)

var _slots: Array[Control]
var _slot_bg: Array[ColorRect]
var _slot_letter: Array[Label]
var _slot_value: Array[Label]
var _slot_border: Array[Panel]
var _selected_index: int = -1
var _placed_indices: Array[int] = []
var _exchange_indices: Array[int] = []
var _exchange_mode: bool = false
var _tile_count: int = 7
var _last_tiles: String = ""


func _ready():
	apply_theme(Settings.dark_mode)
	Settings.theme_changed.connect(apply_theme)
	_build_slots()


func apply_theme(dark: bool):
	if dark:
		_tile_color = Color(0.97, 0.94, 0.84, 1)
		_empty_color = Color(0.14, 0.14, 0.26, 0.55)
		_placed_color = Color(0.40, 0.40, 0.44, 0.75)
		_letter_color = Color(0.10, 0.08, 0.06, 1)
		_placed_letter_color = Color(0.90, 0.90, 0.92, 1)
		_value_color = Color(0.40, 0.32, 0.22, 1)
	else:
		_tile_color = Color(0.99, 0.97, 0.90, 1)
		_empty_color = Color(0.72, 0.68, 0.58, 0.55)
		_placed_color = Color(0.66, 0.64, 0.58, 0.8)
		_letter_color = Color(0.08, 0.06, 0.04, 1)
		_placed_letter_color = Color(0.15, 0.13, 0.10, 1)
		_value_color = Color(0.40, 0.32, 0.22, 1)

	if not _slot_bg.is_empty() and not _last_tiles.is_empty():
		display(_last_tiles, _selected_index, _placed_indices)
	elif not _slot_bg.is_empty():
		for i in range(_tile_count):
			if not _slot_letter[i].visible:
				_slot_bg[i].color = _empty_color


func _build_slots():
	for i in range(_tile_count):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var handler = func(event, idx):
			if (
				event is InputEventMouseButton
				and event.pressed
				and event.button_index == MOUSE_BUTTON_LEFT
			):
				_on_slot_clicked(idx)
		slot.gui_input.connect(handler.bind(i))
		slot.set_drag_forwarding(
			_make_drag_data.bind(i), func(_at, _data): return false, func(_at, _data): pass
		)

		var bg = ColorRect.new()
		bg.name = "BG"
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.position = Vector2.ZERO
		bg.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		bg.color = _empty_color
		slot.add_child(bg)
		_slot_bg.append(bg)

		var letter_label = Label.new()
		letter_label.name = "Letter"
		letter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		letter_label.position = Vector2.ZERO
		letter_label.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter_label.add_theme_font_size_override("font_size", 32)
		letter_label.add_theme_color_override("font_color", _letter_color)
		letter_label.visible = false
		slot.add_child(letter_label)
		_slot_letter.append(letter_label)

		var value_label = Label.new()
		value_label.name = "Value"
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value_label.position = Vector2(SLOT_SIZE * 0.55, SLOT_SIZE * 0.6)
		value_label.size = Vector2(SLOT_SIZE * 0.4, SLOT_SIZE * 0.35)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 14)
		value_label.add_theme_color_override("font_color", _value_color)
		value_label.visible = false
		slot.add_child(value_label)
		_slot_value.append(value_label)

		var border = Panel.new()
		border.name = "Border"
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border.position = Vector2.ZERO
		border.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		border.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		slot.add_child(border)
		_slot_border.append(border)

		add_child(slot)
		_slots.append(slot)

		if i < _tile_count - 1:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(SLOT_GAP, 1)
			add_child(spacer)


func display(tiles: String, selected_index: int = -1, placed_indices: Array[int] = []):
	_selected_index = selected_index
	_placed_indices = placed_indices.duplicate()
	_last_tiles = tiles

	for i in range(_tile_count):
		if i < tiles.length():
			var letter = tiles[i]
			var is_placed = placed_indices.has(i)

			_slot_letter[i].text = letter
			_slot_letter[i].visible = true
			_slot_value[i].text = str(Tiles.get_value(letter))
			_slot_value[i].visible = true

			if is_placed:
				_slot_bg[i].color = _placed_color
				_slot_letter[i].add_theme_color_override("font_color", _placed_letter_color)
				_slot_value[i].add_theme_color_override("font_color", _placed_letter_color)
			else:
				_slot_bg[i].color = _tile_color
				_slot_letter[i].add_theme_color_override("font_color", _letter_color)
				_slot_value[i].add_theme_color_override("font_color", _value_color)
		else:
			_slot_letter[i].visible = false
			_slot_value[i].visible = false
			_slot_bg[i].color = _empty_color

		_update_slot_border(i)


func set_exchange_mode(enabled: bool):
	_exchange_mode = enabled
	if not enabled:
		_exchange_indices = []
	_update_all_borders()


func toggle_exchange_index(index: int):
	if _exchange_indices.has(index):
		_exchange_indices.erase(index)
	else:
		_exchange_indices.append(index)
	_update_slot_border(index)


func get_exchange_indices() -> Array[int]:
	return _exchange_indices.duplicate()


func _make_drag_data(at_position: Vector2, index: int) -> Variant:
	var letter := _slot_letter[index].text if _slot_letter[index].visible else ""
	if letter.is_empty() or _placed_indices.has(index) or _exchange_mode:
		return null
	if _selected_index >= 0 and _selected_index != index:
		_update_slot_border(_selected_index)
	_selected_index = index
	_update_slot_border(index)
	tile_selected.emit(index)
	set_drag_preview(_make_drag_preview(letter))
	return {"index": index, "letter": letter}


func _make_drag_preview(letter: String) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var bg := ColorRect.new()
	bg.color = _tile_color
	bg.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	root.add_child(bg)
	var lbl := Label.new()
	lbl.text = letter
	lbl.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", _letter_color)
	root.add_child(lbl)
	return root


func _on_slot_clicked(index: int):
	var letter = _slot_letter[index].text if _slot_letter[index].visible else ""
	if letter.is_empty():
		return

	if _placed_indices.has(index):
		placed_tile_clicked.emit(index)
		return

	if _exchange_mode:
		toggle_exchange_index(index)
		return

	if _selected_index == index:
		_selected_index = -1
		_update_slot_border(index)
		tile_deselected.emit()
	else:
		if _selected_index >= 0:
			_update_slot_border(_selected_index)
		_selected_index = index
		_update_slot_border(index)
		tile_selected.emit(index)


func _update_slot_border(index: int):
	var border = _slot_border[index]

	if _exchange_mode and _exchange_indices.has(index):
		border.add_theme_stylebox_override("panel", _make_border_style(EXCHANGE_BORDER_COLOR))
	elif _selected_index == index:
		border.add_theme_stylebox_override("panel", _make_border_style(SELECTED_BORDER_COLOR))
	else:
		border.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


func _update_all_borders():
	for i in range(_tile_count):
		_update_slot_border(i)


func _make_border_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style


func get_selected_index() -> int:
	return _selected_index


func get_selected_letter() -> String:
	if _selected_index >= 0 and _slot_letter[_selected_index].visible:
		return _slot_letter[_selected_index].text
	return ""


func clear_selection():
	if _selected_index >= 0:
		_update_slot_border(_selected_index)
	_selected_index = -1
	tile_deselected.emit()
