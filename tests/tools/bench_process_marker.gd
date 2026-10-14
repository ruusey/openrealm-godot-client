extends Node

var bench: BenchWorldNode


func _process(_delta: float) -> void:
	if bench != null:
		bench.mark_process_end()
