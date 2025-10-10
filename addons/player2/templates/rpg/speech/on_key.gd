extends Node

@export var key : int = KEY_ESCAPE

signal key_pressed

func _process(delta: float) -> void:
	if Input.is_key_pressed(key):
		key_pressed.emit()
