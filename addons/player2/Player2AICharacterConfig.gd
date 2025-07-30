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
@export_group("Text To Speech", "tts")
## Enable TTS
@export var tts_enabled : bool = false
## Speed Scale (1 is default)
@export var tts_speed : float = 1
## Default TTS language (overriden if `Player 2 Selected Character` is enabled)
@export var tts_default_language : Player2TTS.Language = Player2TTS.Language.en_US
## Default TTS gender (overriden if `Player 2 Selected Character` is enabled)
@export var tts_default_gender : Player2TTS.Gender = Player2TTS.Gender.FEMALE
