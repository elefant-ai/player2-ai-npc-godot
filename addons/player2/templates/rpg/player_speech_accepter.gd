extends Area2D

signal heard_speech(speech : String)

func accept_speech(speech : String) -> void:
	heard_speech.emit(speech)
