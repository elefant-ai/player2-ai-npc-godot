extends Area2D

func emit_speech(speech : String):
	print("Playing speech: ", speech)
	for area in get_overlapping_areas():
		if area.has_method("accept_speech"):
			area.accept_speech(speech)
