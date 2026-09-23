class_name GameConstants
extends RefCounted

## Constants shared across the world model, renderer and input layer. All of
## them mirror the server; changing one here without changing it there causes
## client/server disagreement rather than a local bug.

## The server runs a fixed-timestep simulation at this rate.
const TICK_RATE := 64.0
const TICK_DELTA := 1.0 / TICK_RATE
const TILE_SIZE := 32
const PLAYER_SIZE := 28
const PLAYER_RENDER_SIZE := 32
## TileManager.collisionTile uses an 85% top-left-anchored hitbox.
const COLLISION_HITBOX_SCALE := 0.85
## Collision is evaluated against map layer 1 (TileManager.getCollisionTiles).
const COLLISION_LAYER := 1

const ENTITY_PLAYER := 0
const ENTITY_ENEMY := 1
const ENTITY_BULLET := 2
