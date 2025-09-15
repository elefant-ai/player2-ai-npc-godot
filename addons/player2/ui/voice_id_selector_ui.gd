@tool
class_name Player2VoiceIdSelectorUI
extends Control

@export var button_scene : PackedScene

@onready var _voice_buttons_list := $"VBoxContainer/ScrollContainer/Voice Buttons"
@onready var _test_text_edit := $"VBoxContainer/Test Text"

signal voice_id_selected(voice_id : String)
signal voice_id_previewed(voice_id : String, text : String)

func add_button(text : String, voice_id : String) -> void:
	if not button_scene:
		printerr("No button scene defined.")
		return
	var b = button_scene.instantiate()
	_voice_buttons_list.add_child(b)
	var b_name : Button = b.find_child("Name")
	var b_play : Button = b.find_child("Play")
	b_name.text = text
	b_name.pressed.connect(func():
		voice_id_selected.emit(voice_id)
	)
	b_play.pressed.connect(func():
		var texts_to_play : PackedStringArray = _test_text_edit.text.split("\n")
		var text_to_play : String = texts_to_play.get(randi_range(0, texts_to_play.size() - 1))
		voice_id_previewed.emit(voice_id, text_to_play)
	)
