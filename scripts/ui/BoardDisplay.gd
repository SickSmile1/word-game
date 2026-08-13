class_name BoardDisplay
extends Control

signal cell_clicked(row: int, col: int)
signal tile_drag_dropped(row: int, col: int, rack_index: int)

const Board = preload("res://scripts/game/Board.gd")
const Tiles = preload("res://scripts/game/Tiles.gd")

var _bonus_colors: Dictionary = {}
var _tile_color: Color
var _preview_color: Color
var _preview_valid_color: Color
var _preview_invalid_color: Color
var _placed_marker_color: Color
var _tile_letter_color: Color
var _tile_value_color: Color
var _grid_color: Color

var _cell_containers: Array
var _cell_bg: Array
var _cell_letter: Array
var _cell_value: Array
var _cell_placed_marker: Array
var _cell_bonus_label: Array
var _cell_size: float = 0.0
var _board_ref: Board = null
var _bonus_board: Board = null
var _built: bool = false
var _last_preview: Array = []
var _last_preview_valid: bool = false
var _grid_bg: ColorRect = null


func _ready():
	_bonus_board = Board.new()
	apply_theme(Settings.dark_mode)
	Settings.theme_changed.connect(apply_theme)
	resized.connect(_on_resized)


func _on_resized():
	if not _built:
		return
	var s = min(size.x, size.y)
	if s <= 0:
		return
	if is_equal_approx(s, _cell_size * Board.SIZE):
		return
	_apply_cell_metrics(s)


# Recomputes positions, sizes and font sizes for every cell so the grid
# fills the current control size. Used after the layout changes (e.g. when
# the device rotates between portrait and landscape).
func _apply_cell_metrics(s: float):
	_cell_size = s / Board.SIZE

	if _grid_bg != null:
		_grid_bg.size = Vector2(s, s)

	for r in range(Board.SIZE):
		for c in range(Board.SIZE):
			var cell: Control = _cell_containers[r][c]
			cell.position = Vector2(c * _cell_size, r * _cell_size)
			cell.size = Vector2(_cell_size, _cell_size)

			var bg: ColorRect = _cell_bg[r][c]
			bg.position = Vector2(1, 1)
			bg.size = Vector2(_cell_size - 2, _cell_size - 2)

			var marker: ColorRect = _cell_placed_marker[r][c]
			marker.position = Vector2(1, 1)
			marker.size = Vector2(_cell_size - 2, _cell_size - 2)

			var letter_label: Label = _cell_letter[r][c]
			letter_label.size = Vector2(_cell_size, _cell_size)
			letter_label.add_theme_font_size_override("font_size", _cell_size * 0.45)

			var value_label: Label = _cell_value[r][c]
			value_label.position = Vector2(_cell_size * 0.55, _cell_size * 0.6)
			value_label.size = Vector2(_cell_size * 0.4, _cell_size * 0.35)
			value_label.add_theme_font_size_override("font_size", _cell_size * 0.17)

			var bonus_label: Label = _cell_bonus_label[r][c]
			bonus_label.size = Vector2(_cell_size, _cell_size)
			bonus_label.add_theme_font_size_override("font_size", _cell_size * 0.22)

	if _board_ref != null:
		display(_board_ref, _last_preview, _last_preview_valid)


func apply_theme(dark: bool):
	if dark:
		_bonus_colors = {
			Board.BONUS_NONE: Color(0.22, 0.22, 0.36, 1),
			Board.BONUS_DL: Color(0.08, 0.62, 0.72, 1),
			Board.BONUS_TL: Color(0.16, 0.50, 0.94, 1),
			Board.BONUS_DW: Color(0.88, 0.24, 0.24, 1),
			Board.BONUS_TW: Color(0.78, 0.10, 0.16, 1),
		}
		_tile_color = Color(0.97, 0.94, 0.84, 1)
		_preview_color = Color(0.96, 0.93, 0.68, 1)
		_preview_valid_color = Color(0.10, 0.68, 0.30, 1)
		_preview_invalid_color = Color(0.72, 0.16, 0.16, 1)
		_placed_marker_color = Color(0.91, 0.27, 0.38, 0.55)
		_tile_letter_color = Color(0.10, 0.08, 0.06, 1)
		_tile_value_color = Color(0.40, 0.32, 0.22, 1)
		_grid_color = Color(0.06, 0.06, 0.14, 1)
	else:
		_bonus_colors = {
			Board.BONUS_NONE: Color(0.88, 0.82, 0.68, 1),
			Board.BONUS_DL: Color(0.46, 0.84, 0.92, 1),
			Board.BONUS_TL: Color(0.32, 0.66, 0.94, 1),
			Board.BONUS_DW: Color(0.94, 0.46, 0.50, 1),
			Board.BONUS_TW: Color(0.88, 0.22, 0.26, 1),
		}
		_tile_color = Color(0.99, 0.97, 0.90, 1)
		_preview_color = Color(0.97, 0.94, 0.78, 1)
		_preview_valid_color = Color(0.22, 0.78, 0.36, 1)
		_preview_invalid_color = Color(0.86, 0.22, 0.22, 1)
		_placed_marker_color = Color(0.84, 0.24, 0.31, 0.55)
		_tile_letter_color = Color(0.08, 0.06, 0.04, 1)
		_tile_value_color = Color(0.40, 0.32, 0.22, 1)
		_grid_color = Color(0.52, 0.46, 0.34, 1)

	if _grid_bg != null:
		_grid_bg.color = _grid_color

	if _built:
		if _board_ref != null:
			display(_board_ref, _last_preview, _last_preview_valid)
		else:
			for r in range(Board.SIZE):
				for c in range(Board.SIZE):
					var bonus = _bonus_board.get_bonus(r, c)
					_cell_bg[r][c].color = _bonus_colors.get(bonus, _bonus_colors[Board.BONUS_NONE])


func _ensure_built():
	if _built:
		return
	_built = true

	var s = min(size.x, size.y)
	if s <= 0:
		s = 1020

	_cell_size = s / Board.SIZE

	_grid_bg = ColorRect.new()
	_grid_bg.name = "GridBG"
	_grid_bg.position = Vector2.ZERO
	_grid_bg.size = Vector2(s, s)
	_grid_bg.color = _grid_color
	add_child(_grid_bg)

	_cell_containers = []
	_cell_bg = []
	_cell_letter = []
	_cell_value = []
	_cell_placed_marker = []
	_cell_bonus_label = []

	for r in range(Board.SIZE):
		_cell_containers.append([])
		_cell_bg.append([])
		_cell_letter.append([])
		_cell_value.append([])
		_cell_placed_marker.append([])
		_cell_bonus_label.append([])

		for c in range(Board.SIZE):
			var cell = _create_cell(r, c)
			add_child(cell)
			_cell_containers[r].append(cell)


func _create_cell(row: int, col: int) -> Control:
	var cell = Control.new()
	cell.position = Vector2(col * _cell_size, row * _cell_size)
	cell.size = Vector2(_cell_size, _cell_size)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.gui_input.connect(
		func(event):
			if (
				event is InputEventMouseButton
				and event.pressed
				and event.button_index == MOUSE_BUTTON_LEFT
			):
				cell_clicked.emit(row, col)
	)
	cell.set_drag_forwarding(
		func(_at): return null, _can_accept_drop.bind(row, col), _on_tile_dropped.bind(row, col)
	)

	var bg = ColorRect.new()
	bg.name = "BG"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = Vector2(1, 1)
	bg.size = Vector2(_cell_size - 2, _cell_size - 2)
	var bonus = _bonus_board.get_bonus(row, col)
	bg.color = _bonus_colors.get(bonus, _bonus_colors[Board.BONUS_NONE])
	cell.add_child(bg)
	_cell_bg[row].append(bg)

	var marker = ColorRect.new()
	marker.name = "Marker"
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.position = Vector2(1, 1)
	marker.size = Vector2(_cell_size - 2, _cell_size - 2)
	marker.color = _placed_marker_color
	marker.visible = false
	cell.add_child(marker)
	_cell_placed_marker[row].append(marker)

	var letter_label = Label.new()
	letter_label.name = "Letter"
	letter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letter_label.position = Vector2.ZERO
	letter_label.size = Vector2(_cell_size, _cell_size)
	letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter_label.add_theme_font_size_override("font_size", _cell_size * 0.45)
	letter_label.add_theme_color_override("font_color", _tile_letter_color)
	letter_label.visible = false
	cell.add_child(letter_label)
	_cell_letter[row].append(letter_label)

	var value_label = Label.new()
	value_label.name = "Value"
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.position = Vector2(_cell_size * 0.55, _cell_size * 0.6)
	value_label.size = Vector2(_cell_size * 0.4, _cell_size * 0.35)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", _cell_size * 0.17)
	value_label.add_theme_color_override("font_color", _tile_value_color)
	value_label.visible = false
	cell.add_child(value_label)
	_cell_value[row].append(value_label)

	var bonus_label = Label.new()
	bonus_label.name = "Bonus"
	bonus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bonus_label.position = Vector2.ZERO
	bonus_label.size = Vector2(_cell_size, _cell_size)
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bonus_label.add_theme_font_size_override("font_size", _cell_size * 0.22)
	bonus_label.add_theme_color_override("font_color", Color.WHITE)
	bonus_label.visible = false
	cell.add_child(bonus_label)
	_cell_bonus_label[row].append(bonus_label)

	return cell


func display(board: Board, preview_placements: Array = [], preview_valid: bool = false):
	_ensure_built()
	_board_ref = board
	_last_preview = preview_placements.duplicate()
	_last_preview_valid = preview_valid
	var preview_set = {}
	for p in preview_placements:
		preview_set[Vector2i(p.x, p.y)] = true

	for r in range(Board.SIZE):
		for c in range(Board.SIZE):
			var letter = board.get_tile(r, c)
			var is_preview = preview_set.has(Vector2i(r, c))

			if letter.is_empty() and not is_preview:
				_cell_letter[r][c].visible = false
				_cell_value[r][c].visible = false
				_cell_placed_marker[r][c].visible = false
				_cell_bg[r][c].color = _bonus_colors.get(
					_bonus_board.get_bonus(r, c), _bonus_colors[Board.BONUS_NONE]
				)
				_show_bonus_label(r, c)
			else:
				_cell_bonus_label[r][c].visible = false
				var display_letter = letter if not letter.is_empty() else "?"
				_cell_letter[r][c].text = display_letter
				_cell_letter[r][c].add_theme_color_override("font_color", _tile_letter_color)
				_cell_letter[r][c].visible = true
				_cell_value[r][c].text = str(Tiles.get_value(display_letter))
				_cell_value[r][c].add_theme_color_override("font_color", _tile_value_color)
				_cell_value[r][c].visible = true
				if is_preview:
					_cell_bg[r][c].color = (
						_preview_valid_color if preview_valid else _preview_invalid_color
					)
				else:
					_cell_bg[r][c].color = _tile_color
				_cell_placed_marker[r][c].color = _placed_marker_color
				_cell_placed_marker[r][c].visible = is_preview


func highlight_cells(positions: Array, highlight: bool = true):
	_ensure_built()
	for p in positions:
		if p.x >= 0 and p.x < Board.SIZE and p.y >= 0 and p.y < Board.SIZE:
			_cell_placed_marker[p.x][p.y].visible = highlight


func get_cell_center(row: int, col: int) -> Vector2:
	return Vector2(col * _cell_size + _cell_size / 2, row * _cell_size + _cell_size / 2)


func _show_bonus_label(row: int, col: int):
	var bonus = _bonus_board.get_bonus(row, col)
	var label_text := ""

	match bonus:
		Board.BONUS_DL:
			label_text = "DL"
		Board.BONUS_TL:
			label_text = "TL"
		Board.BONUS_DW:
			label_text = "DW"
		Board.BONUS_TW:
			label_text = "TW"

	if label_text.is_empty():
		_cell_bonus_label[row][col].visible = false
	else:
		_cell_bonus_label[row][col].text = label_text
		_cell_bonus_label[row][col].visible = true


func _can_accept_drop(at_position: Vector2, data: Variant, row: int, col: int) -> bool:
	if not (data is Dictionary and data.has("letter")):
		return false
	if _board_ref == null:
		return false
	return not _board_ref.is_occupied(row, col)


func _on_tile_dropped(at_position: Vector2, data: Variant, row: int, col: int) -> void:
	var idx: int = int(data.get("index", -1)) if data is Dictionary else -1
	tile_drag_dropped.emit(row, col, idx)
