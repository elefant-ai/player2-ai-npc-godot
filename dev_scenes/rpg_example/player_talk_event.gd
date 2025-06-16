class_name PlayerTalkEvent
extends Node

signal player_talked(message : String)

func talk(message : String) -> void:
	player_talked.emit(message)
