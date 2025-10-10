class_name SpeechBubble
extends TextEdit

@onready var timer = $Timer

func play(message : String):
	self.show()
	self.text = message
	timer.start()

func _ready():
	self.hide()
