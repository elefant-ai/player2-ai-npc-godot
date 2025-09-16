@tool
class_name Player2AICharacterConfig
extends Resource

## Text to Speech
@export_group("Text 2 Speech", "tts")
@export var tts_enabled : bool = true
@export var tts : Player2TTSConfig = Player2TTSConfig.new()

func _property_can_revert(property: StringName) -> bool:
	return property == "tts"

func _property_get_revert(property: StringName) -> Variant:
	if property == "tts":
		return Player2TTSConfig.new()
	return null
