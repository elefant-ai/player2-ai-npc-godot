extends Node

func _ready() -> void:
	var p2tts : Player2TTS = $Player2TTS
	var text : TextEdit = $VBoxContainer/TextEdit
	var speak_button : Button = $VBoxContainer/Button
	var voice_text : TextEdit = $"VBoxContainer/HBoxContainer/Voice ID"
	var voice_instructions : TextEdit = $"VBoxContainer/Voice Instructions"
	var stream_toggle : CheckButton = $"VBoxContainer/HBoxContainer/VBoxContainer/Stream Checkbox"
	var mp3_toggle : CheckButton = $"VBoxContainer/HBoxContainer/VBoxContainer/Mp3 Checkbox"

	voice_text.text = p2tts.config.voice_id
	voice_text.text_changed.connect(func():
		p2tts.config.voice_id = voice_text.text
	)
	stream_toggle.button_pressed = p2tts.config.stream
	stream_toggle.pressed.connect(func():
		print("STREAM SET: ", stream_toggle.button_pressed)
		p2tts.config.stream = stream_toggle.button_pressed
		)
	mp3_toggle.pressed.connect(func():
		print("Mp3 SET: ", mp3_toggle.button_pressed)
		p2tts.config.use_wav = not mp3_toggle.button_pressed
		mp3_toggle.text = "Mp3" if mp3_toggle.button_pressed else "WAV"
		)

	speak_button.pressed.connect(func():
		p2tts.speak(text.text, [], voice_instructions.text)
	)
