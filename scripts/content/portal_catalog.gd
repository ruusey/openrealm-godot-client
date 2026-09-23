class_name PortalCatalog
extends RefCounted

## Resolves a portal's portalId into its art and its name.
##
## Only the id travels on the wire, so a NetPortal copied field-by-field is a
## portal with no sprite -- which is exactly the bug the native client's
## `NetPortal.asPortal()` carries a comment about ("reflection field-copy skips
## sprite loading, leaving sprite=null"). Both references look the definition
## up out of portals.json the moment the portal lands.

var _library: ContentLibrary
var _sprites: SpriteCache


func _init(library: ContentLibrary, sprites: SpriteCache) -> void:
	_library = library
	_sprites = sprites


## Portal art is a plain cell on a shared sheet, sliced exactly like a tile's.
func texture(portal_id: int) -> AtlasTexture:
	return _sprites.atlas_for(definition(portal_id))


## The content's own name for the portal -- "Vault_Portal", "Beach_0_Portal".
## Distinct from NetPortal.targetLabel, which names the realm on the far side
## and is what the player is shown.
func name(portal_id: int) -> String:
	return definition(portal_id).get("portalName", "Portal_%d" % portal_id)


func definition(portal_id: int) -> Dictionary:
	return _library.portals.get(portal_id, {})
