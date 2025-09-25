extends Node

func _ready() -> void:
	var p2tts : Player2TTS = $Player2TTS
	var text : TextEdit = $VBoxContainer/TextEdit
	var speak_button : Button = $VBoxContainer/Button
	var voice_text : TextEdit = $"VBoxContainer/HBoxContainer/Voice ID"
	var stream_toggle : CheckButton = $VBoxContainer/HBoxContainer/CheckButton

	voice_text.text = p2tts.config.voice_id
	voice_text.text_changed.connect(func():
		p2tts.config.voice_id = voice_text.text
	)
	stream_toggle.button_pressed = p2tts.config.stream
	stream_toggle.pressed.connect(func():
		print("STREAM SET: ", stream_toggle.button_pressed)
		p2tts.config.stream = stream_toggle.button_pressed
		)

	speak_button.pressed.connect(func():
		p2tts.speak(text.text)
	)
