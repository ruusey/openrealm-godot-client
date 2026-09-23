#!/usr/bin/env python3
"""
Generate golden wire vectors for the GDScript codec tests.

This is a deliberately *independent* implementation of the Java wire format
(java.io.DataOutputStream semantics + PacketCompression framing), written
straight from the Java source. If the GDScript codec and this script agree on
the same bytes, two independent readings of the spec agree -- which is the
closest we can get to a conformance test without standing up the Java server.

Usage:
    python3 tools/gen_golden.py <java-src-root> [-o tests/golden]
"""
import argparse
import json
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_schema import parse_file, PRIMITIVES  # noqa: E402

HEADER_SIZE = 5
COMPRESSION_FLAG = 0x80
COMPRESSION_THRESHOLD = 128


def load_schema(src_root):
    packets, entities, ids = {}, {}, {}
    for dirpath, _dirs, files in os.walk(src_root):
        for f in files:
            if not f.endswith(".java"):
                continue
            r = parse_file(os.path.join(dirpath, f))
            if not r:
                continue
            name, pid, fields = r
            if name in packets or name in entities:
                continue
            if pid is None:
                entities[name] = fields
            else:
                packets[name] = fields
                ids[name] = pid
    return packets, entities, ids


class Writer:
    def __init__(self):
        self.buf = bytearray()

    def prim(self, t, v):
        if t == "byte":
            self.buf += struct.pack(">b", int(v))
        elif t == "bool":
            self.buf += struct.pack(">B", 1 if v else 0)
        elif t == "short":
            self.buf += struct.pack(">h", int(v))
        elif t == "int":
            self.buf += struct.pack(">i", int(v))
        elif t == "long":
            self.buf += struct.pack(">q", int(v))
        elif t == "float":
            self.buf += struct.pack(">f", float(v))
        elif t == "string":
            b = (v or "").encode("utf-8")
            self.buf += struct.pack(">i", len(b)) + b
        else:
            raise ValueError(t)


def meaningful(value):
    """A value that is not the Java default for its type."""
    return value is not None and value != 0 and value is not False and value != ""


def mask_for(sections, data):
    """Which optional sections this value carries, as a bitmask byte."""
    if data.get("_mask") is not None:
        return int(data["_mask"])
    mask = 0
    for bit, fields in sections:
        if any(meaningful(data.get(f[0])) for f in fields):
            mask |= bit
    return mask


def write_fields(w, fields, data, entities):
    for name, wtype, is_coll, sections in fields:
        if wtype == "mask":
            mask = mask_for(sections, data)
            w.buf += struct.pack(">B", mask)
            for bit, section_fields in sections:
                if mask & bit:
                    write_fields(w, section_fields, data, entities)
        elif is_coll:
            items = data.get(name, [])
            w.buf += struct.pack(">i", len(items))
            for it in items:
                write_value(w, wtype, it, entities)
        else:
            write_value(w, wtype, data.get(name), entities)


def write_value(w, wtype, value, entities):
    if wtype in PRIMITIVES.values():
        w.prim(wtype, value)
    else:
        write_fields(w, entities[wtype], value or {}, entities)


def default_for(wtype, entities):
    if wtype == "string":
        return ""
    if wtype == "bool":
        return False
    if wtype == "float":
        return 0.0
    if wtype in PRIMITIVES.values():
        return 0
    return fill_defaults(entities[wtype], {}, entities)


def fill_defaults(fields, data, entities):
    """Expand a partial test value into every field, so the JSON expectation is total.

    Fields inside a masked section that the mask leaves out are *not* filled:
    they never reach the wire, so the decoder cannot produce them either.
    """
    out = {}
    for name, wtype, is_coll, sections in fields:
        if wtype == "mask":
            mask = mask_for(sections, data)
            out[name] = mask
            for bit, section_fields in sections:
                if mask & bit:
                    out.update(fill_defaults(section_fields, data, entities))
        elif is_coll:
            items = data.get(name, [])
            out[name] = [
                (it if wtype in PRIMITIVES.values() else fill_defaults(entities[wtype], it, entities))
                for it in items
            ]
        elif wtype in PRIMITIVES.values():
            out[name] = data.get(name, default_for(wtype, entities))
        else:
            out[name] = fill_defaults(entities[wtype], data.get(name, {}) or {}, entities)
    return out


def frame(packet_id, payload, force_raw=False):
    """Mirror of PacketCompression.compressFrame."""
    if not force_raw and len(payload) > COMPRESSION_THRESHOLD:
        # Java: new Deflater(Deflater.BEST_SPEED) -> zlib-wrapped, level 1.
        deflated = zlib.compress(payload, 1)
        if len(deflated) < len(payload):
            total = HEADER_SIZE + 4 + len(deflated)
            return (
                struct.pack(">B", packet_id | COMPRESSION_FLAG)
                + struct.pack(">i", total)
                + struct.pack(">i", len(payload))
                + deflated
            )
    return struct.pack(">B", packet_id) + struct.pack(">i", HEADER_SIZE + len(payload)) + payload


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src_root")
    ap.add_argument("-o", "--outdir", default=None)
    args = ap.parse_args()

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    outdir = args.outdir or os.path.join(root, "tests", "golden")
    os.makedirs(outdir, exist_ok=True)

    packets, entities, ids = load_schema(os.path.abspath(args.src_root))

    def net_tile(tid, layer, x, y):
        return {"tileId": tid, "layer": layer, "xIndex": x, "yIndex": y}

    def net_player(pid, name, cls, x, y):
        return {
            "id": pid, "name": name, "accountUuid": "acct-%d" % pid,
            "characterUuid": "char-%d" % pid, "classId": cls, "size": 28,
            "pos": {"x": x, "y": y}, "dX": 0.5, "dY": -0.25, "shortId": pid % 1000,
            "chatRole": "player", "dyeId": 0,
        }

    cases = [
        # --- client -> server input, exercised on the write path ---
        # v0.9.0 dropped the leading entityId/playerId from these: the server
        # takes the sender from the connection.
        ("PlayerMovePacket", {"seq": 42, "vx": 0.70710678, "vy": -0.70710678}),
        ("HeartbeatPacket", {"timestamp": 1758412800123}),
        ("PlayerShootPacket", {"projectileId": 123456789012345,
                               "projectileGroupId": 77, "destX": 100.5, "destY": -200.25,
                               "srcX": 1.0, "srcY": 2.0}),
        ("UseAbilityPacket", {"posX": 12.5, "posY": -12.5, "abilityIndex": 3}),
        ("UsePortalPacket", {"portalId": 555, "fromRealmId": 1, "toVault": 0, "toNexus": 1}),
        # --- signed-boundary sweep: every primitive at its Java extremes ---
        ("TestPacket", {"test0": "", "test1": "unicode: ☠ é \U0001f600",
                        "test2": -9223372036854775808, "test3": -32768,
                        "test4": [True, False, True, True]}),
        ("NetStatsBoundary::UpdatePacket", None),  # placeholder, replaced below
        # --- nested entities + collections, server -> client ---
        ("LoadMapPacket", {
            "realmId": -1, "mapId": 3, "dungeonId": 7, "mapWidth": 128, "mapHeight": 128,
            "tiles": [net_tile(i % 253, i % 3, i * 2, i * 3) for i in range(5)],
        }),
        ("UnloadPacket", {"players": [1, 2, 3], "bullets": [], "enemies": [9223372036854775807],
                          "containers": [0], "portals": [-1]}),
        ("PlayerStatePacket", {"playerId": 42, "health": 1200, "mana": 300,
                               "effectIds": [4, 7, 12], "effectTimes": [1000, 2000, 3000]}),
        ("ObjectMovePacket", {"movements": [
            {"entityId": 1, "entityType": 0, "posX": 10.0, "posY": 20.0, "velX": 0.5, "velY": 0.0, "flags": 1},
            {"entityId": 2, "entityType": 1, "posX": -10.5, "posY": 0.25, "velX": 0.0, "velY": -1.5, "flags": 0},
        ]}),
        ("CompactMovePacket", {"movements": [
            {"shortEntityId": -1, "posX": 1.5, "posY": 2.5, "velXFixed": 32767, "velYFixed": -32768, "flags": 255 - 256},
        ]}),
        ("CommandPacket", {"playerId": 0, "commandId": 1,
                           "command": json.dumps({"email": "a@b.c", "password": "pw",
                                                  "characterUuid": "uuid-1", "token": None})}),
    ]

    def net_bullet(bid, **overrides):
        base = {
            "id": bid, "projectileId": 7, "size": 16, "pos": {"x": 1.5, "y": -2.5},
            "dX": 0.5, "dY": -0.5, "angle": 1.25, "magnitude": 8.0, "range": 320.0,
            "damage": 45, "length": 0, "lifetimeTicks": 64, "srcEntityId": 991,
            "createdTime": 1758412800123, "flags": [1, 4],
        }
        base.update(overrides)
        return base

    # One bullet per mask combination: straight (no sections), wavy, orbiting,
    # homing, and a sprite override -- plus one carrying all four at once.
    cases.append(("LoadPacket", {
        "players": [], "enemies": [], "containers": [], "portals": [], "difficulty": 1,
        "bullets": [
            net_bullet(1),
            net_bullet(2, invert=True, timeStep=16, amplitude=12, frequency=3),
            net_bullet(3, orbitCenterX=10.0, orbitCenterY=-10.0,
                       orbitRadius=48.0, orbitPhase=1.5),
            net_bullet(4, targetEntityId=123456789012345),
            net_bullet(5, overrideSpriteKey="bullets.png", overrideSpriteRow=2,
                       overrideSpriteCol=3, overrideSpriteSize=8, overrideSpriteHeight=8),
            net_bullet(6, invert=True, timeStep=1, amplitude=1, frequency=1,
                       orbitCenterX=1.0, orbitCenterY=1.0, orbitRadius=1.0, orbitPhase=1.0,
                       targetEntityId=42, overrideSpriteKey="x.png", overrideSpriteRow=1,
                       overrideSpriteCol=1, overrideSpriteSize=1, overrideSpriteHeight=1),
        ],
    }))

    # A LoadPacket big enough to cross the compression threshold.
    cases = [c for c in cases if c[0] != "NetStatsBoundary::UpdatePacket"]
    cases.append(("LoadPacket", {
        "players": [net_player(1000 + i, "Player%d" % i, i % 12, i * 32.0, i * 16.0) for i in range(6)],
        "enemies": [{"id": 5000 + i, "enemyId": i, "weaponId": 0, "size": 16,
                     "pos": {"x": i * 8.0, "y": i * 4.0}, "dX": 0.0, "dY": 0.0,
                     "difficulty": 1.5, "health": 100, "maxHealth": 100, "shortId": i}
                    for i in range(8)],
        "bullets": [], "containers": [], "portals": [], "difficulty": 2,
    }))

    manifest = []
    blob = bytearray()
    for name, value in cases:
        if name not in packets:
            print(f"  ! skipping {name}: not in this source tree", file=sys.stderr)
            continue
        fields = packets[name]
        full = fill_defaults(fields, value, entities)
        w = Writer()
        write_fields(w, fields, full, entities)
        payload = bytes(w.buf)
        f = frame(ids[name], payload)
        manifest.append({
            "packet": name,
            "id": ids[name],
            "offset": len(blob),
            "frame_size": len(f),
            "payload_size": len(payload),
            "compressed": bool(f[0] & COMPRESSION_FLAG),
            "payload_hex": payload.hex(),
            "expected": full,
        })
        blob += f

    with open(os.path.join(outdir, "frames.bin"), "wb") as fh:
        fh.write(blob)
    with open(os.path.join(outdir, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=1)

    ncomp = sum(1 for m in manifest if m["compressed"])
    print(f"wrote {outdir}: {len(manifest)} frames, {len(blob)} bytes, {ncomp} compressed")
    for m in manifest:
        print(f"  {m['packet']:<24} id={m['id']:<4} payload={m['payload_size']:<6} "
              f"frame={m['frame_size']:<6} {'deflate' if m['compressed'] else 'raw'}")


if __name__ == "__main__":
    main()
