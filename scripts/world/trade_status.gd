class_name TradeStatus
extends RefCounted

## What a trade's two selections say, and the packet ours goes out as.


## The packet that carries our table: the flags, no item refs, unconfirmed
## -- a change always un-confirms, as the server will when it hears.
static func selection_packet(local_id: int, selected: Array) -> Dictionary:
	return {"selection": {"playerId": local_id, "selection": selected.duplicate(),
		"itemRefs": [], "confirmed": false}}


## A side counts as confirmed while a closed trade is held on screen too:
## that is the state that closed it.
static func confirmed(side: Dictionary, closing: bool) -> bool:
	return closing or bool(side.get("confirmed", false))


## The web client's four lines.
static func line(mine: Dictionary, theirs: Dictionary, closing: bool, partner: String) -> String:
	var we_did := confirmed(mine, closing)
	var they_did := confirmed(theirs, closing)
	if we_did and they_did:
		return "Trade confirmed!"
	if we_did:
		return "Waiting for %s to confirm" % partner
	if they_did:
		return "%s confirmed - confirm to trade" % partner
	return "Selecting items"
