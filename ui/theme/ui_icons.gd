## Pictures for menus (spec 12.4): Kenney Game Icons by name, colour swatches, and rounded
## coloured tiles with a white icon on top. Textures are cached.
class_name UiIcons
extends RefCounted

const DIR := "res://assets/third_party/kenney/game_icons/"
const SIZE := 72

static var _cache := {}


static func icon(name: String) -> Texture2D:
	var path := DIR + name + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Rounded square in `color`, optionally with the named white icon centred on it.
static func tile(color: Color, icon_name: String = "", size: int = SIZE) -> Texture2D:
	var key := "%s|%s|%d" % [color.to_html(), icon_name, size]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.22
	for y in size:
		for x in size:
			var dx := maxf(maxf(r - x, x - (size - 1 - r)), 0.0)
			var dy := maxf(maxf(r - y, y - (size - 1 - r)), 0.0)
			var d := sqrt(dx * dx + dy * dy)
			if d <= r:
				var edge := clampf(r - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(color, edge))
	var tex: Texture2D = icon(icon_name) if icon_name != "" else null
	if tex:
		var ii := tex.get_image()
		if ii:
			if ii.is_compressed():
				ii.decompress()
			ii.convert(Image.FORMAT_RGBA8)
			var inner := int(size * 0.7)
			ii.resize(inner, inner, Image.INTERPOLATE_BILINEAR)
			img.blend_rect(ii, Rect2i(0, 0, inner, inner), Vector2i((size - inner) / 2, (size - inner) / 2))
	var out := ImageTexture.create_from_image(img)
	_cache[key] = out
	return out
