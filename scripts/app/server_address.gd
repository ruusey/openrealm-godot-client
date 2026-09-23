class_name ServerAddress
extends RefCounted

## Turns a ClientConfig into the addresses to actually dial.
##
## Separate from ClientConfig because this is where the awkward rules live --
## which scheme, which port is implied, whether a proxy route replaces the
## server's own listener -- and each of them is worth testing on its own.
## ClientConfig decides what was asked for; this decides where that is.


## The port to dial, defaulting to the listener the transport speaks to.
static func game_port(config: ClientConfig) -> int:
	if config.port > 0:
		return config.port
	return ClientConfig.WEBSOCKET_PORT if config.websocket else ClientConfig.TCP_PORT


## Base URL for the data service.
static func data_url(config: ClientConfig) -> String:
	return "%s://%s" % ["https" if config.secure else "http", authority(config)]


## The host, plus the port unless the scheme already implies it -- so a
## deployed setup keeps producing a plain "https://play.example".
static func authority(config: ClientConfig) -> String:
	var implied := PageOrigin.HTTPS_PORT if config.secure else PageOrigin.HTTP_PORT
	if config.data_port == implied:
		return config.host
	return "%s:%d" % [config.host, config.data_port]


## The address to dial for the game server.
##
## A WebSocket url carries its own scheme, and a page served over TLS cannot
## open an insecure socket, so it has to be wss there. Raw TCP has no scheme
## at all. A host written with a scheme already -- --host=wss://play.example
## -- is left exactly as it was written.
##
## With a socket path, the address is the *page's* origin plus that route: the
## proxy is listening on 443, not on the game server's own port, so the path
## takes the place of that listener rather than being added to it.
static func game_host(config: ClientConfig) -> String:
	if not config.websocket or config.host.contains("://"):
		return config.host
	var scheme := "wss" if config.secure else "ws"
	if config.socket_path != "":
		return "%s://%s%s" % [scheme, authority(config), config.socket_path]
	return "%s://%s" % [scheme, config.host]
