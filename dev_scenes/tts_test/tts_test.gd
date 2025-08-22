extends Node

func _ready() -> void:
	$Button.pressed.connect(func():
		$Player2TTS.speak($TextEdit.text)
		)
