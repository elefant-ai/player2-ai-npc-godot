extends Node

@export var obj_to_destroy : Node

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_K) and obj_to_destroy:
		obj_to_destroy.queue_free()
