## Small drawn HUD pictures (spec 12.4): sun or moon, coin, heart, envelope. Drawn so they need
## no image files and stay crisp at any text scale.
class_name HudIcon
extends Control

enum Kind { SUN, MOON, COIN, HEART, MAIL, WATER }

var kind: Kind = Kind.COIN


func _init(k: Kind = Kind.COIN, size_px := 44.0) -> void:
	kind = k
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_kind(k: Kind) -> void:
	if k != kind:
		kind = k
		queue_redraw()


func _draw() -> void:
	var s := size
	var c := s * 0.5
	var r := minf(s.x, s.y) * 0.42
	var ink := Color(0, 0, 0, 0.35)
	match kind:
		Kind.SUN:
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.75, c + Vector2(cos(a), sin(a)) * r * 1.15, Color("ffb627"), 4.0, true)
			draw_circle(c, r * 0.62, Color("ffd23f"))
		Kind.MOON:
			draw_circle(c, r * 0.85, Color("f4f1de"))
			draw_circle(c + Vector2(r * 0.42, -r * 0.25), r * 0.75, Color(0.18, 0.2, 0.35))
		Kind.COIN:
			draw_circle(c, r, Color("d99a1e"))
			draw_circle(c, r * 0.78, Color("ffcf40"))
			draw_rect(Rect2(c - Vector2(r * 0.12, r * 0.42), Vector2(r * 0.24, r * 0.84)), Color("d99a1e"))
		Kind.HEART:
			var hr := r * 0.5
			draw_circle(c + Vector2(-hr * 0.85, -hr * 0.35), hr, Color("e5534b"))
			draw_circle(c + Vector2(hr * 0.85, -hr * 0.35), hr, Color("e5534b"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.9, -r * 0.05), c + Vector2(r * 0.9, -r * 0.05), c + Vector2(0, r * 0.95)]), Color("e5534b"))
		Kind.MAIL:
			var rect := Rect2(c - Vector2(r, r * 0.68), Vector2(r * 2, r * 1.36))
			draw_rect(rect, Color("fdf6e9"))
			draw_rect(rect, ink, false, 2.0)
			draw_polyline(PackedVector2Array([rect.position, c + Vector2(0, r * 0.1), rect.position + Vector2(rect.size.x, 0)]), Color("e5534b"), 3.0, true)
		Kind.WATER:
			draw_circle(c + Vector2(0, r * 0.25), r * 0.62, Color("3f8fd8"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, r * 0.05), c + Vector2(r * 0.55, r * 0.05), c + Vector2(0, -r * 0.95)]), Color("3f8fd8"))
