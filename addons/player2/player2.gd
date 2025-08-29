@tool
class_name Player2
extends EditorPlugin

const ASYNC_HELPER_AUTOLOAD_NAME = "Player2AsyncHelper"
const ASYNC_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/async_helper.gd"

const ERROR_HELPER_AUTOLOAD_NAME = "Player2ErrorHelper"
const ERROR_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/error_helper.tscn"

const WEB_HELPER_AUTOLOAD_NAME = "Player2WebHelper"
const WEB_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/web_helper.gd"

const AUTH_HELPER_AUTOLOAD_NAME = "Player2AuthHelper"
const AUTH_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/auth_helper.gd"

const API_SOURCE_HELPER_AUTOLOAD_NAME = "Player2APISourceHelper"
const API_SOURCE_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/Player2APISource.tscn"

const API_HELPER_AUTOLOAD_NAME = "Player2API"
const API_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/api.gd"


func _enter_tree() -> void:
	# Settings
	# Client ID
	if not ProjectSettings.has_setting("player2/client_id"):
		var default : String = ""
		ProjectSettings.set_setting("player2/client_id", default)
		ProjectSettings.add_property_info({
			"name": "player2/client_id",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE
		})
	# TODO: This breaks godot/crashes the loading, so if this ever gets fixed add it back in since it's so nice!!
	# API settings
	#if not ProjectSettings.has_setting("player2/api"):
		#var default : string = Player2APIConfig.new()
		#ProjectSettings.set_setting("player2/api", default)
		#ProjectSettings.add_property_info({
			#"name": "player2/api",
			#"type": TYPE_STRING,
			#"hint": PROPERTY_HINT_RESOURCE_TYPE,
			#"hint_string": "Player2APIConfig"
		#})
	#elif !ProjectSettings.get("player2/api"):
		#ProjectSettings.set_setting("player2/api", Player2APIConfig.new())

	# game_key is Deprecated
	if ProjectSettings.has_setting("player2/game_key"):
		ProjectSettings.clear("player2/game_key")
	ProjectSettings.set_as_basic("player2/client_id", true)
	#ProjectSettings.set_as_basic("player2/api", true)

	add_autoload_singleton(ASYNC_HELPER_AUTOLOAD_NAME, ASYNC_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(ERROR_HELPER_AUTOLOAD_NAME, ERROR_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(API_SOURCE_HELPER_AUTOLOAD_NAME, API_SOURCE_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(WEB_HELPER_AUTOLOAD_NAME, WEB_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(AUTH_HELPER_AUTOLOAD_NAME, AUTH_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(API_HELPER_AUTOLOAD_NAME, API_HELPER_AUTOLOAD_PATH)

	# Initialization of the plugin goes here.
	add_custom_type("Player2AINPC", "Player2AINPC", preload("nodes/Player2AINPC.gd"), preload("p2.svg"))
	add_custom_type("Player2STT", "Player2STT", preload("nodes/Player2STT.gd"), preload("p2.svg"))
	add_custom_type("Player2TTS", "Player2TTS", preload("nodes/Player2TTS.gd"), preload("p2.svg"))
	add_custom_type("Player2AIChatCompletion", "Player2AIChatCompletion.gd", preload("nodes/Player2AIChatCompletion.gd"), preload("p2.svg"))


func _exit_tree() -> void:
	# Settings
	ProjectSettings.clear("player2/client_id")
	#ProjectSettings.clear("player2/api", true)

	remove_autoload_singleton(API_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(AUTH_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(WEB_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(API_SOURCE_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(ERROR_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(ASYNC_HELPER_AUTOLOAD_NAME)

	# Clean-up of the plugin goes here.
	remove_custom_type("Player2AINPC")
	remove_custom_type("Player2STT")
	remove_custom_type("Player2TTS")
	remove_custom_type("Player2AIChatCompletion")


func _enable_plugin() -> void:
	pass
func _disable_plugin() -> void:
	pass
