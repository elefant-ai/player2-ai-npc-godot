class_name SpeechBubble
extends TextEdit

@onready var timer = $Timer

func play(message : String):
	self.show()
	self.scale = Vector2(1, 0)
	self.create_tween().tween_property(self, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_EXPO)
	self.text = message
	timer.start()

func fade():
	self.create_tween().tween_property(self, "scale", Vector2(1, 0), 0.5).set_trans(Tween.TRANS_EXPO)
#
#func _ready():
	#self.hide()
