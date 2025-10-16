extends Node

func _ready() -> void:
	$VBoxContainer/Button.pressed.connect(func():
		print("press")
		$Player2AIImageGeneration.generate_image($VBoxContainer/TextEdit.text)
	)
	$Player2AIImageGeneration.generation_succeeded.connect(func(image : Image):
		var tex := ImageTexture.create_from_image(image)
		$VBoxContainer/TextureRect.texture = tex
	)
