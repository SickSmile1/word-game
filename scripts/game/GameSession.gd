class_name GameSession
extends RefCounted

enum Player { P0 = 0, P1 = 1 }

const Board = preload("res://scripts/game/Board.gd")
const TileBag = preload("res://scripts/game/TileBag.gd")

const PROTOCOL_VERSION := 1

var board: Board
var bag_pool: Array[String] = []
var bag_count: int = 0
var racks: Array[String] = ["", ""]
var scores: Array[int] = [0, 0]
var consecutive_passes: int = 0
var turn: int = Player.P0
var game_over: bool = false
var last_action_text: String = ""


func new_game() -> void:
	board = Board.new()
	var bag := TileBag.new()
	racks[Player.P0] = bag.draw_balanced_tiles(7)
	racks[Player.P1] = bag.draw_balanced_tiles(7)
	bag_pool = bag._pool.duplicate()
	bag_count = bag_pool.size()
	scores = [0, 0]
	consecutive_passes = 0
	turn = Player.P0
	game_over = false
	last_action_text = ""


func to_dict_for_player(me: int) -> Dictionary:
	var cells := []
	for r in range(15):
		var row := []
		for c in range(15):
			row.append(board.get_tile(r, c) if board.is_occupied(r, c) else null)
		cells.append(row)

	var data := {
		"version": PROTOCOL_VERSION,
		"board": cells,
		"scores": scores.duplicate(),
		"passes": consecutive_passes,
		"turn": turn,
		"game_over": game_over,
		"bag_count": bag_pool.size(),
		"last_action": last_action_text,
	}

	if me == Player.P0:
		data["racks"] = racks.duplicate()
		data["bag"] = bag_pool.duplicate()
	else:
		data["racks"] = ["*".repeat(racks[Player.P0].length()), racks[Player.P1]]
	return data


static func from_dict_for_player(data: Dictionary, _me: int) -> GameSession:
	var s: GameSession = (load("res://scripts/game/GameSession.gd") as GDScript).new()
	s.board = Board.new()
	var board_data: Array = data.get("board", [])
	for r in range(board_data.size()):
		var row: Array = board_data[r]
		for c in range(row.size()):
			if (
				row[c] != null
				and typeof(row[c]) == TYPE_STRING
				and not (row[c] as String).is_empty()
			):
				s.board.place_tile(r, c, row[c])
	s.scores = (data.get("scores", [0, 0]) as Array).duplicate()
	s.consecutive_passes = int(data.get("passes", 0))
	s.turn = int(data.get("turn", 0))
	s.game_over = bool(data.get("game_over", false))
	s.bag_count = int(data.get("bag_count", 0))
	s.last_action_text = String(data.get("last_action", ""))
	var racks_data: Array = data.get("racks", ["", ""])
	s.racks[Player.P0] = racks_data[Player.P0]
	s.racks[Player.P1] = racks_data[Player.P1]
	if data.has("bag"):
		s.bag_pool = (data.get("bag", []) as Array).duplicate()
	return s
