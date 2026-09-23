extends GutTest

## Integrity of the generated schema. These guard the generator's output rather
## than the codec: a duplicate id or an unresolved field type would fail at
## runtime as a silent desync, so it is caught here instead.

const PRIMITIVES := ["byte", "bool", "short", "int", "long", "float", "string"]


## Every field of a type, with masked sections flattened in -- the codec merges
## a present section into its parent Dictionary, so for naming and type
## resolution the section fields are fields of the parent.
func _flatten(fields: Array) -> Array:
	var out: Array = []
	for field in fields:
		if field[1] == "mask":
			for section in field[3]:
				out.append_array(_flatten(section[1]))
		else:
			out.append(field)
	return out

func test_packet_ids_are_unique():
	var seen := {}
	for name in NetSchema.PACKET_IDS:
		var id: int = NetSchema.PACKET_IDS[name]
		assert_false(seen.has(id), "packet id %d claimed by both %s and %s" % [id, seen.get(id, ""), name])
		seen[id] = name


func test_packet_ids_fit_in_seven_bits():
	# The high bit of the id byte is the compression flag, so ids must be 0-127.
	for name in NetSchema.PACKET_IDS:
		var id: int = NetSchema.PACKET_IDS[name]
		assert_between(id, 0, 127, "%s has id %d, which collides with the compression flag" % [name, id])


func test_name_and_id_maps_agree():
	for name in NetSchema.PACKET_IDS:
		assert_eq(NetSchema.PACKET_NAMES[NetSchema.PACKET_IDS[name]], name, "%s round-trips id <-> name" % name)
	assert_eq(NetSchema.PACKET_NAMES.size(), NetSchema.PACKET_IDS.size())


func test_every_field_type_resolves():
	for table in [NetSchema.PACKETS, NetSchema.ENTITIES]:
		for type_name in table:
			for field in _flatten(table[type_name]):
				var wire_type: String = field[1]
				if wire_type in PRIMITIVES:
					continue
				assert_true(NetSchema.is_known(wire_type),
					"%s.%s references unknown type '%s'" % [type_name, field[0], wire_type])


func test_field_tuples_are_well_formed():
	for table in [NetSchema.PACKETS, NetSchema.ENTITIES]:
		for type_name in table:
			for field in _flatten(table[type_name]):
				assert_eq(field.size(), 3, "%s: field tuple is [name, type, is_collection]" % type_name)
				assert_typeof(field[0], TYPE_STRING)
				assert_typeof(field[1], TYPE_STRING)
				assert_typeof(field[2], TYPE_BOOL)


func test_masked_section_blocks_are_well_formed():
	for table in [NetSchema.PACKETS, NetSchema.ENTITIES]:
		for type_name in table:
			for field in table[type_name]:
				if field[1] != "mask":
					continue
				assert_eq(field.size(), 4, "%s: a mask tuple carries its sections" % type_name)
				assert_false(field[2], "%s: a mask block is not a collection" % type_name)
				var bits := {}
				for section in field[3]:
					var bit: int = section[0]
					assert_between(bit, 1, 255, "%s: section bit %d does not fit the mask byte"
						% [type_name, bit])
					assert_eq(bit & (bit - 1), 0, "%s: section bit %d is not a single bit"
						% [type_name, bit])
					assert_false(bits.has(bit), "%s: two sections claim bit %d" % [type_name, bit])
					bits[bit] = true
					assert_false(section[1].is_empty(), "%s: empty section" % type_name)


func test_field_names_are_unique_within_a_type():
	for table in [NetSchema.PACKETS, NetSchema.ENTITIES]:
		for type_name in table:
			var seen := {}
			for field in _flatten(table[type_name]):
				assert_false(seen.has(field[0]), "%s has two fields named %s" % [type_name, field[0]])
				seen[field[0]] = true


func test_every_packet_has_a_field_table():
	for name in NetSchema.PACKET_IDS:
		assert_true(NetSchema.PACKETS.has(name), "%s has no field table" % name)


func test_core_packets_are_present():
	# The vertical slice depends on exactly these; losing one to a generator
	# regression should fail loudly here rather than as an empty screen.
	for name in ["CommandPacket", "PlayerMovePacket", "HeartbeatPacket", "LoadMapPacket",
			"LoadPacket", "UnloadPacket", "ObjectMovePacket", "CompactMovePacket",
			"UpdatePacket", "PlayerStatePacket", "PlayerPosAckPacket"]:
		assert_true(NetSchema.PACKET_IDS.has(name), "%s missing from the schema" % name)


func test_known_wire_ids_match_the_documented_catalog():
	assert_eq(NetSchema.PACKET_IDS["PlayerMovePacket"], 1)
	assert_eq(NetSchema.PACKET_IDS["UpdatePacket"], 2)
	assert_eq(NetSchema.PACKET_IDS["ObjectMovePacket"], 3)
	assert_eq(NetSchema.PACKET_IDS["HeartbeatPacket"], 5)
	assert_eq(NetSchema.PACKET_IDS["CommandPacket"], 7)
	assert_eq(NetSchema.PACKET_IDS["LoadMapPacket"], 8)
	assert_eq(NetSchema.PACKET_IDS["LoadPacket"], 9)
	assert_eq(NetSchema.PACKET_IDS["UnloadPacket"], 10)
	assert_eq(NetSchema.PACKET_IDS["PlayerStatePacket"], 24)
	assert_eq(NetSchema.PACKET_IDS["CompactMovePacket"], 25)
	assert_eq(NetSchema.PACKET_IDS["PlayerPosAckPacket"], 26)


func test_fields_for_returns_empty_for_unknown_types():
	assert_eq(NetSchema.fields_for("NotAThing"), [])
	assert_false(NetSchema.is_known("NotAThing"))
	assert_true(NetSchema.is_known("NetTile"))
	assert_true(NetSchema.is_known("LoadPacket"))


func test_vector2f_is_two_floats():
	assert_eq(NetSchema.fields_for("Vector2f"), [["x", "float", false], ["y", "float", false]])


func test_bullets_carry_their_optional_groups_in_a_mask():
	# v0.9.0 gates the wavy / orbit / homing / sprite-override groups behind a
	# mask byte. Losing the block to a generator regression would silently
	# shorten every bullet on the wire.
	var blocks := 0
	for field in NetSchema.fields_for("NetBullet"):
		if field[1] == "mask":
			blocks += 1
			assert_eq(field[3].size(), 4, "wavy, orbit, homing and sprite override")
	assert_eq(blocks, 1, "NetBullet carries exactly one masked-section block")


func test_source_tree_is_recorded():
	assert_ne(NetSchema.SOURCE_TREE, "", "the schema records which Java tree produced it")
