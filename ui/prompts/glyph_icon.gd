## Device-aware button glyph (plan P1.21, spec 2.8). Draws the native-colored disc and label
## from the active GlyphSetDef until real textures exist. Shape (label) is always shown, so
## color is never the only signal (K4).
class_name GlyphIcon
extends Control

const SETS := [
	preload("res://resources/glyphs/xbox.tres"),
	preload("res://resources/glyphs/playstation.tres"),
	preload("res://resources/glyphs/nintendo.tres"),
	preload("res://resources/glyphs/kbm.tres"),
]

@export var button: StringName = &"face_left"

var glyph_set: GlyphSetDef = SETS[3]


func _ready() -> void:
	custom_minimum_size = Vector2(48, 48)
	EventBus.input_device_changed.connect(_on_device)
	set_glyph_set(InputService.current_glyphs())


func set_glyph_set(index: int) -> void:
	glyph_set = SETS[index]
	queue_redraw()


func label_text() -> String:
	return String(glyph_set.labels.get(button, "?"))


func color() -> Color:
	return glyph_set.colors.get(button, Color.WHITE)


func _on_device(_kind: int, glyph_index: int) -> void:
	set_glyph_set(glyph_index)


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	draw_circle(size * 0.5, r, color())
	var font := get_theme_default_font()
	var text := label_text()
	var fs := int(r * (0.9 if text.length() <= 2 else 0.45))
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, Vector2((size.x - ts.x) * 0.5, (size.y + ts.y * 0.6) * 0.5), text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.BLACK)
