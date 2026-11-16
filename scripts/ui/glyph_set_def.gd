## Button glyph set for one controller family (spec 2.8). Textures are placeholders
## until art exists; `labels` and `colors` drive the fallback glyph drawing.
class_name GlyphSetDef
extends Resource

@export var id: StringName
## Button name (e.g. &"face_bottom") -> display label ("A", "Cross", ...)
@export var labels: Dictionary = {}
## Button name -> native color
@export var colors: Dictionary = {}
## Button name -> Texture2D (optional)
@export var textures: Dictionary = {}
