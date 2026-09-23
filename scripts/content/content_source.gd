class_name ContentSource
extends RefCounted

## Where game content is read from.
##
## Two of them: the data repo checked out beside this one, and the data
## service over HTTP. A browser has no filesystem, so a web build is obliged
## to use the second; the desktop uses the first, so local work needs nothing
## running.
##
## One flat namespace either way. On disk that means trying data/, entity/ and
## ui/ in turn; the service's /game-data handler is configured with the same
## fallback, so "tiles.json" or "rotmg-misc.png" resolves identically through
## both and nothing above here has to know which is in use.
##
## `read` is declared as an ordinary function but every caller awaits it: the
## HTTP implementation is a coroutine and the file one is not, and awaiting a
## value that never suspends simply returns it. That is what keeps the desktop
## path synchronous without a second set of call sites.


## Returns [Error, PackedByteArray].
func read(_name: String) -> Array:
	return [ERR_UNAVAILABLE, PackedByteArray()]


## Why this source cannot be used at all, or "" when it can. Reported once, in
## place of an identical missing-file error for every content file.
func unavailable() -> String:
	return ""


## Where content is coming from, for the startup log.
func describe() -> String:
	return "nowhere"
