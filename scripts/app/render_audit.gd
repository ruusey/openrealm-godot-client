class_name RenderAudit
extends RefCounted

## What the client is spending on things no one can see.
##
## A hidden CanvasLayer draws nothing, so a screen left running behind the
## game costs CPU, not draw calls: the sign-in hall once simulated its
## torches for the whole session, hidden (999f80a). The rule this checks is
## the one that fix follows. A panel's own layer may poll while hidden --
## that is how a panel decides to show itself -- but nothing UNDER a hidden
## layer may process, by script or inside the engine. `hidden_work` names
## every node that breaks it.
##
## For what IS drawn, `visible_by_layer` counts the drawable items each
## top-level layer holds, and FrameCounts reads the frame's total; the
## live audit (tests/visual/live_render_audit.gd) draws each layer alone
## to see what it costs.


## Every node that processes although the layer it sits under is hidden,
## as "layer/path (class)".
static func hidden_work(root: Node) -> PackedStringArray:
	var found := PackedStringArray()
	_walk(root, null, found)
	return found


## Top-level layer -> the CanvasItems under it that would draw now. A
## hidden layer, or one with nothing showing, is left out.
static func visible_by_layer(root: Node) -> Dictionary:
	var counts := {}
	for layer in layers(root):
		if not layer.visible:
			continue
		var shown := 0
		for item in layer.find_children("*", "CanvasItem", true, false):
			if item.is_visible_in_tree():
				shown += 1
		if shown > 0:
			counts[label(layer)] = shown
	return counts


## The pieces a frame is made of: every CanvasLayer and every CanvasItem
## with no canvas above it, wherever it sits under the root -- the world
## renderer hangs off Main, a plain Node, not off the root.
static func layers(root: Node) -> Array:
	var out := []
	for node in root.find_children("*", "", true, false):
		if (node is CanvasLayer or node is CanvasItem) and not _under_canvas(node, root):
			out.append(node)
	return out


static func _under_canvas(node: Node, root: Node) -> bool:
	var up := node.get_parent()
	while up != null and up != root:
		if up is CanvasLayer or up is CanvasItem:
			return true
		up = up.get_parent()
	return false


static func _walk(node: Node, layer: CanvasLayer, found: PackedStringArray) -> void:
	if layer != null and not layer.is_visible() and _busy(node):
		found.append("%s/%s (%s)" % [label(layer), layer.get_path_to(node), _kind(node)])
	var under := node as CanvasLayer if node is CanvasLayer else layer
	# A layer inside a hidden layer is hidden with it.
	if node is CanvasLayer and layer != null and not layer.is_visible():
		under = layer
	for child in node.get_children():
		_walk(child, under, found)


## A script's _process or _physics_process, or the engine's own processing
## inside a built-in node -- a running Timer, an HTTPRequest in flight, a
## caret blinking, smooth scrolling -- which no script shows.
static func _busy(node: Node) -> bool:
	return node.is_processing() or node.is_physics_processing() \
		or node.is_processing_internal() or node.is_physics_processing_internal()


## A node by its script's class when it has one -- what `.new()` names a
## node is "@CanvasLayer@13", which says nothing.
static func label(node: Node) -> String:
	return _kind(node) if String(node.name).begins_with("@") else String(node.name)


static func _kind(node: Node) -> String:
	var script: Script = node.get_script()
	if script != null and script.get_global_name() != "":
		return script.get_global_name()
	return node.get_class()
