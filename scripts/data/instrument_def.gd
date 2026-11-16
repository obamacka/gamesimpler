## Instrument (spec 3.4, 7.4). Notes are generated tones of the major scale from base_hz
## until recorded samples exist.
class_name InstrumentDef
extends Resource

const MAJOR := [0, 2, 4, 5, 7, 9, 11, 12]

@export var id: StringName
@export var base_hz := 440.0
@export var wave: StringName = &"sine"


func note_hz(i: int) -> float:
	return base_hz * pow(2.0, MAJOR[clampi(i, 0, 7)] / 12.0)
