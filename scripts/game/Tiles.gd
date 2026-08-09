class_name Tiles
extends RefCounted

const TILE_VALUES := {
	"A": 1,
	"B": 3,
	"C": 4,
	"D": 1,
	"E": 1,
	"F": 4,
	"G": 2,
	"H": 2,
	"I": 1,
	"J": 6,
	"K": 4,
	"L": 2,
	"M": 3,
	"N": 1,
	"O": 2,
	"P": 4,
	"Q": 10,
	"R": 1,
	"S": 1,
	"T": 1,
	"U": 1,
	"V": 6,
	"W": 3,
	"X": 8,
	"Y": 10,
	"Z": 3,
	"Ä": 6,
	"Ö": 8,
	"Ü": 6,
}

const DISTRIBUTION := {
	"A": 5,
	"B": 2,
	"C": 2,
	"D": 4,
	"E": 15,
	"F": 2,
	"G": 3,
	"H": 4,
	"I": 6,
	"J": 1,
	"K": 2,
	"L": 3,
	"M": 4,
	"N": 9,
	"O": 3,
	"P": 1,
	"Q": 1,
	"R": 6,
	"S": 7,
	"T": 6,
	"U": 6,
	"V": 1,
	"W": 1,
	"X": 1,
	"Y": 1,
	"Z": 2,
	"Ä": 1,
	"Ö": 1,
	"Ü": 1,
}

const TOTAL_TILES := 101


static func get_value(letter: String) -> int:
	return TILE_VALUES.get(letter.to_upper(), 0)


static func get_rack_value(rack: String) -> int:
	var total := 0
	for c in rack:
		total += get_value(c)
	return total
