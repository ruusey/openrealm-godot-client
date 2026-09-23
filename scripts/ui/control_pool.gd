class_name ControlPool
extends RefCounted

## Controls kept by key from one frame to the next.
##
## The web client keeps its name labels, damage numbers and status icons in
## pools keyed by entity, acquired each frame and hidden when nothing
## acquired them; this is that. A Control acquired by a key stays that key's
## across frames -- so a Label keeps its shaped text and only moves -- and
## whatever a frame did not acquire is freed at the sweep, so a horde that
## walked off does not leave its nodes behind.

var _parent: Node
var _make: Callable
var _live := {}
var _touched := {}


func _init(parent: Node, make: Callable) -> void:
	_parent = parent
	_make = make


func acquire(key: Variant) -> Control:
	var control: Control = _live.get(key)
	if control == null:
		control = _make.call()
		_parent.add_child(control)
		_live[key] = control
	control.visible = true
	_touched[key] = true
	return control


## Frees every Control this frame did not acquire.
func sweep() -> void:
	for key in _live.keys():
		if not _touched.has(key):
			_live[key].queue_free()
			_live.erase(key)
	_touched.clear()


func size() -> int:
	return _live.size()
