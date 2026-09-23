class_name ForgePixel
extends RefCounted

## Which pixel of the sprite a crystal paints.
##
## The wire wants one -- ForgeEnchantPacket carries a pixelX and pixelY the
## server paints in the stat's colour and refuses if already painted -- and
## the web client makes the player click it on a magnified sprite. There is
## no such editor here: the client takes the first opaque pixel not yet
## painted, reading the sprite's own alpha, so a forge is a button press.

## When the sprite cannot be read at all: the server only checks that the
## pixel is not already taken, so the corner is a valid answer.
const FALLBACK := Vector2i.ZERO


static func pick(texture: Texture2D, item: Dictionary) -> Vector2i:
	var taken := painted(item)
	var image := _image_of(texture)
	if image == null:
		return _first_free(taken, 8, 8)
	var region := _region_of(texture, image)
	for y in region.size.y:
		for x in region.size.x:
			var at := Vector2i(x, y)
			if at in taken:
				continue
			if image.get_pixel(region.position.x + x, region.position.y + y).a > 0.0:
				return at
	return _first_free(taken, region.size.x, region.size.y)


## The pixels already spoken for: every crystal's, and the gem's.
static func painted(item: Dictionary) -> Array:
	var out: Array = []
	for enchantment in item.get("enchantments", []):
		out.append(Vector2i(int(enchantment.get("pixelX", 0)), int(enchantment.get("pixelY", 0))))
	if int(item.get("gemstoneType", 0)) != 0:
		out.append(Vector2i(int(item.get("gemPixelX", 0)), int(item.get("gemPixelY", 0))))
	return out


static func _image_of(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var source: Texture2D = texture.atlas if texture is AtlasTexture else texture
	return source.get_image() if source != null else null


static func _region_of(texture: Texture2D, image: Image) -> Rect2i:
	if texture is AtlasTexture:
		return Rect2i(texture.region)
	return Rect2i(Vector2i.ZERO, image.get_size())


static func _first_free(taken: Array, width: int, height: int) -> Vector2i:
	for y in height:
		for x in width:
			if not Vector2i(x, y) in taken:
				return Vector2i(x, y)
	return FALLBACK
