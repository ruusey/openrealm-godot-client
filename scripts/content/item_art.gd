class_name ItemArt
extends RefCounted

## An item's icon with its forge enchantments and gem painted onto the sprite --
## the same one-pixel-per-mount overlay the web and native clients draw, each in
## the stat's colour at the pixel the player chose, so an enchanted weapon visibly
## differs from a plain one. Built once per distinct enchant configuration and
## cached; a plain item returns its catalog atlas untouched.

static var _cache := {}


## The item's texture with its painted pixels, or the plain atlas when it carries
## none. `item` is a wire item dict (enchantments[], gemstoneType, gemPixel*).
static func textured(content: GameData, item: Dictionary) -> Texture2D:
	var base: Texture2D = content.item_texture(int(item.get("itemId", -1))) if content else null
	var mark_list := marks(item)
	if base == null or mark_list.is_empty():
		return base
	var key := _key(item, mark_list)
	if _cache.has(key):
		return _cache[key]
	var painted := _paint(base, mark_list)
	var texture: Texture2D = painted if painted != null else base
	_cache[key] = texture
	return texture


## Every painted pixel as [Vector2i(x, y), Color]. The gem comes after the
## crystals, so it wins a shared pixel exactly as the server paints them.
static func marks(item: Dictionary) -> Array:
	var out: Array = []
	for enchantment in item.get("enchantments", []):
		out.append([Vector2i(int(enchantment.get("pixelX", 0)), int(enchantment.get("pixelY", 0))),
			argb_color(int(enchantment.get("pixelColor", 0)))])
	if int(item.get("gemstoneType", 0)) != 0:
		out.append([Vector2i(int(item.get("gemPixelX", 0)), int(item.get("gemPixelY", 0))),
			argb_color(int(item.get("gemPixelColor", 0)))])
	return out


## Server pixelColor is ARGB with alpha in the high byte; a zero alpha is the
## Java default for "opaque", not "invisible", so treat it as full.
static func argb_color(argb: int) -> Color:
	var a := (argb >> 24) & 0xff
	if a == 0:
		a = 0xff
	return Color8((argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff, a)


static func _key(item: Dictionary, mark_list: Array) -> String:
	var parts := PackedStringArray()
	for mark in mark_list:
		parts.append("%d,%d,%d" % [mark[0].x, mark[0].y, int(mark[1].to_rgba32())])
	return "%d#%s#%s" % [int(item.get("itemId", -1)), str(item.get("uid", "")), ",".join(parts)]


static func _paint(base: Texture2D, mark_list: Array) -> Texture2D:
	var image: Image = null
	var region := Rect2i()
	if base is AtlasTexture:
		var sheet: Texture2D = base.atlas
		image = sheet.get_image() if sheet != null else null
		region = Rect2i(base.region)
	else:
		image = base.get_image()
		region = Rect2i(Vector2i.ZERO, image.get_size()) if image != null else Rect2i()
	if image == null or region.size.x <= 0:
		return null
	var cell := image.get_region(region)
	for mark in mark_list:
		var at: Vector2i = mark[0]
		if at.x >= 0 and at.x < cell.get_width() and at.y >= 0 and at.y < cell.get_height():
			cell.set_pixel(at.x, at.y, mark[1])
	return ImageTexture.create_from_image(cell)
