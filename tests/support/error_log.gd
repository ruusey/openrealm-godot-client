class_name ErrorLog
extends Logger

## Hears every engine and script error while it is attached. A drawer that
## errors is abandoned mid-draw and the renderer counts it anyway, and GUT
## counts an errored test as passing, so a count alone cannot see a broken
## drawer: attach one of these around the draw and assert it heard nothing.
##
##   var log := ErrorLog.new()
##   OS.add_logger(log)
##   ...draw...
##   OS.remove_logger(log)
##   assert_eq(log.errors, [])

var errors: Array = []


func _log_error(function: String, file: String, line: int, _code: String, rationale: String,
		_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	errors.append("%s:%d %s %s" % [file, line, function, rationale])
