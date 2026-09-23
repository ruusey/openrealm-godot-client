extends GutTest

## Bytes held for a delay, both ways, in order.

var inner: FakeTransport
var lag: LagTransport
var now := 1000


func before_each():
	now = 1000
	inner = FakeTransport.new()
	lag = LagTransport.new(inner, 50.0)
	lag.clock = func() -> int: return now
	lag.connect_to_host("h", 1)
	inner.status = StreamPeerTCP.STATUS_CONNECTED


func test_inbound_bytes_arrive_the_delay_later_in_one_stream():
	inner.incoming = PackedByteArray([1, 2, 3])
	lag.poll()
	assert_eq(lag.get_available_bytes(), 0, "held")
	assert_eq(inner.incoming.size(), 0, "but taken off the socket at once")
	now += 20
	inner.incoming = PackedByteArray([4, 5])
	lag.poll()
	now += 30
	lag.poll()
	assert_eq(lag.get_available_bytes(), 3, "the first parcel is due, the second is not")
	assert_eq(lag.get_data(2), [OK, PackedByteArray([1, 2])], "partial reads, like a socket")
	now += 20
	lag.poll()
	assert_eq(lag.get_data(10), [OK, PackedByteArray([3, 4, 5])])


func test_outbound_bytes_leave_the_delay_later():
	lag.put_data(PackedByteArray([9]))
	lag.poll()
	assert_eq(inner.sent.size(), 0)
	now += 50
	lag.poll()
	assert_eq(inner.sent, PackedByteArray([9]))
	assert_eq(lag.in_flight(), 0)


func test_jitter_never_reorders_a_stream():
	lag = LagTransport.new(inner, 50.0, 40.0, 7)
	lag.clock = func() -> int: return now
	var dues: Array[float] = []
	for i in 20:
		dues.append(lag._due("in", float(now)))
		now += 1
	for i in 19:
		assert_true(dues[i + 1] >= dues[i], "parcel %d is due after parcel %d" % [i + 1, i])
	assert_ne(dues[0], dues[5], "and they are not all the same: there is jitter")


func test_status_and_no_delay_pass_through_and_a_disconnect_drops_what_is_held():
	assert_eq(lag.get_status(), StreamPeerTCP.STATUS_CONNECTED)
	lag.set_no_delay(true)
	assert_true(inner.no_delay_set)
	lag.put_data(PackedByteArray([1]))
	inner.incoming = PackedByteArray([2])
	lag.poll()
	assert_eq(lag.in_flight(), 2)
	lag.disconnect_from_host()
	assert_eq(lag.in_flight(), 0)
	assert_eq(inner.disconnect_count, 1)
	assert_eq(inner.sent.size(), 0, "never sent")


func test_before_connecting_a_write_goes_straight_to_the_socket():
	inner.status = StreamPeerTCP.STATUS_CONNECTING
	assert_eq(lag.put_data(PackedByteArray([1])), OK)
	assert_eq(inner.sent, PackedByteArray([1]), "the socket says what it thinks of it")


func test_the_flag_wraps_the_real_transport():
	var config := ClientConfig.parse(PackedStringArray(["--lag=100", "--lag-jitter=4"]), false, {})
	assert_eq(config.lag_ms, 100.0)
	assert_eq(config.lag_jitter_ms, 4.0)
	var transport := config.open_transport()
	assert_true(transport is LagTransport)
	assert_true(transport.inner is TcpTransport)
	assert_eq(transport.one_way_ms, 100.0)
	var plain: LagTransport = ClientConfig.parse(PackedStringArray([]), false, {}).open_transport()
	assert_false(plain.delaying(), "no flag: a delay line at no delay")


func test_at_no_delay_bytes_pass_straight_through():
	lag.one_way_ms = 0.0
	lag.put_data(PackedByteArray([1]))
	assert_eq(inner.sent, PackedByteArray([1]), "written at once, not a poll later")
	inner.incoming = PackedByteArray([2])
	lag.poll()
	assert_eq(lag.get_data(1), [OK, PackedByteArray([2])], "readable on the same poll")
	# Something already in flight from a delay that was just switched off is
	# still let out in order, and the write queues behind it.
	lag.one_way_ms = 50.0
	lag.put_data(PackedByteArray([3]))
	lag.one_way_ms = 0.0
	lag.put_data(PackedByteArray([4]))
	assert_eq(inner.sent, PackedByteArray([1]), "queued behind the parcel in flight")
	now += 50
	lag.poll()
	assert_eq(inner.sent, PackedByteArray([1, 3, 4]))


func test_the_key_steps_the_delay_round():
	lag.one_way_ms = 0.0
	lag.jitter_ms = 0.0
	var seen: Array[float] = []
	for i in LagTransport.STEPS.size():
		seen.append(lag.cycle())
	assert_eq(seen, [50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 350.0, 0.0], "50 at a time to 350, then none")
	assert_eq(lag.jitter_ms, 0.0, "none at no delay")
	lag.cycle()
	assert_eq(lag.jitter_ms, LagTransport.STEP_JITTER_MS)
	lag.one_way_ms = 75.0
	assert_eq(lag.cycle(), 50.0, "a value the key did not set restarts the round")
