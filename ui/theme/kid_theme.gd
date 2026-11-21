## Picture-first theme for young players (spec 12.4): big rounded buttons and panels, a bold
## default font, a thick orange focus outline. Built in code; Accessibility sets it as the root
## theme with the text scale applied.
class_name KidTheme
extends RefCounted

const INK := Color("3d2f4a")            # text on light surfaces
const PAPER := Color("fdf6e9")          # panel background
const BUTTON := Color("fffaf0")
const BUTTON_EDGE := Color("e6d6b8")
const FOCUS := Color("ff9f1c")          # focus outline: visible on light and coloured tiles
const GO := Color("4caf50")
const STOP := Color("e5534b")
const CHOOSE := Color("3f8fd8")
const MONEY := Color("f2b632")
const EXTRA := Color("8e6bc8")
const BASE_FONT := 26


static func build(text_scale: float = 1.0) -> Theme:
	var t := Theme.new()
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.6
	t.default_font = font
	t.default_font_size = int(round(BASE_FONT * text_scale))

	t.set_stylebox("normal", "Button", box(BUTTON, 20, 3, BUTTON_EDGE, 4))
	t.set_stylebox("hover", "Button", box(Color("fff3d6"), 20, 3, BUTTON_EDGE, 4))
	t.set_stylebox("pressed", "Button", box(Color("ffe1a8"), 20, 3, BUTTON_EDGE, 2))
	t.set_stylebox("disabled", "Button", box(Color(0.93, 0.92, 0.9, 0.7), 20, 3, Color(0.85, 0.83, 0.8, 0.7), 0))
	t.set_stylebox("focus", "Button", focus_box())
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.4))
	t.set_constant("h_separation", "Button", 18)
	t.set_constant("icon_max_width", "Button", 72)

	var panel := box(Color(PAPER, 0.97), 32, 4, Color(1, 1, 1, 0.9), 14)
	panel.content_margin_left = 28
	panel.content_margin_right = 28
	panel.content_margin_top = 24
	panel.content_margin_bottom = 24
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_color("font_color", "Label", INK)

	var bg := box(Color(0, 0, 0, 0.18), 12, 0, Color.TRANSPARENT, 0)
	var fill := box(GO, 12, 0, Color.TRANSPARENT, 0)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)

	# Tabs: rounded, the selected one light and the rest muted.
	var tab_on := box(BUTTON, 16, 3, FOCUS, 0)
	tab_on.corner_radius_bottom_left = 0
	tab_on.corner_radius_bottom_right = 0
	var tab_off := box(Color(INK, 0.12), 16, 0, Color.TRANSPARENT, 0)
	tab_off.corner_radius_bottom_left = 0
	tab_off.corner_radius_bottom_right = 0
	for tt in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", tt, tab_on)
		t.set_stylebox("tab_unselected", tt, tab_off)
		t.set_stylebox("tab_hovered", tt, box(Color("fff3d6"), 16, 0, Color.TRANSPARENT, 0))
		t.set_stylebox("tab_focus", tt, focus_box())
		t.set_color("font_selected_color", tt, INK)
		t.set_color("font_unselected_color", tt, Color(INK, 0.65))
		t.set_color("font_hovered_color", tt, INK)
	t.set_stylebox("panel", "TabContainer", box(Color(1, 1, 1, 0.5), 18, 0, Color.TRANSPARENT, 0))

	var grab := box(Color(INK, 0.45), 10, 0, Color.TRANSPARENT, 0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(FOCUS, 10, 0, Color.TRANSPARENT, 0))
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.08), 10, 0, Color.TRANSPARENT, 0))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 16)
	t.set_constant("h_separation", "GridContainer", 18)
	t.set_constant("v_separation", "GridContainer", 18)
	return t


static func box(bg: Color, radius: int, border: int, border_color: Color, shadow: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.shadow_size = shadow
	s.shadow_color = Color(0, 0, 0, 0.18)
	s.shadow_offset = Vector2(0, shadow * 0.5)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.anti_aliasing = true
	return s


static func focus_box() -> StyleBoxFlat:
	var s := box(Color.TRANSPARENT, 24, 7, FOCUS, 0)
	s.expand_margin_left = 5
	s.expand_margin_right = 5
	s.expand_margin_top = 5
	s.expand_margin_bottom = 5
	return s


## A solid coloured button style (picture tiles): the colour is the meaning (spec 12.4).
static func tile_styles(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", box(color, 28, 4, color.lightened(0.35), 6))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.12), 28, 4, color.lightened(0.45), 6))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.15), 28, 4, color.lightened(0.2), 2))
	b.add_theme_stylebox_override("disabled", box(Color(color, 0.35), 28, 4, Color(1, 1, 1, 0.3), 0))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	b.add_theme_constant_override("outline_size", 6)
