@tool
class_name Player2OpeningUI
extends Control

signal closed(dont_show_again : bool)
signal template_opened(template_path : PackedScene)

func _ready() -> void:
	for child in $"VBoxContainer/Template List/HBoxContainer".get_children():
		if child.has_signal('pressed') and "template_scene" in child:
			child.pressed.connect(func():
				template_opened.emit(child.template_scene)
			)
			

func close():
	closed.emit($"VBoxContainer/Bottom Row/HBoxContainer/Dont Show Again Checkbox".button_pressed)
