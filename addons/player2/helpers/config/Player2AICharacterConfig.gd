@tool
class_name Player2AICharacterConfig
extends Resource

## Selected character from the Player 2 Launcher
@export_group ("Player 2 Selected Character", "use_player2_selected_character")
## If true, will grab information about the player's selected agents from the Player 2 Launcher
@export var use_player2_selected_character : bool = false:
	set(val):
		use_player2_selected_character = val
		# for the agent to make updates
		notify_property_list_changed()

## If there are multiple agents (CURRENTLY UNSUPPORTED), pick this index. Set to -1 to automatically pick a unique agent
@export_range(-1, 99999) var use_player2_selected_character_desired_index : int = -1

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
