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

const API_HELPER_AUTOLOAD_NAME = "Player2API"
const API_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/api.gd"

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	add_custom_type("Player2AINPC", "Player2AINPC", preload("Player2AINPC.gd"), preload("p2.svg"))
	add_custom_type("Player2STT", "Player2STT", preload("Player2STT.gd"), preload("p2.svg"))
	# Settings
	# Game Key
	if not ProjectSettings.has_setting("player2/game_key"):
		var default : String = ProjectSettings.get_setting("application/config/name")
		if !default:
			default = "my_game"
		default = default.replace(" ", "_").replace(":", "_")
		ProjectSettings.set_setting("player2/game_key", default)
		ProjectSettings.add_property_info({
			"name": "player2/game_key",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE
		})
	# Client ID
	if not ProjectSettings.has_setting("player2/client_id"):
		var default : String = ""
		ProjectSettings.set_setting("player2/client_id", default)
		ProjectSettings.add_property_info({
			"name": "player2/client_id",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE
		})
	# API settings
	if not ProjectSettings.has_setting("player2/api"):
		var default : Player2APIConfig = Player2APIConfig.new()
		ProjectSettings.set_setting("player2/api", default)
		ProjectSettings.add_property_info({
			"name": "player2/api",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Player2APIConfig"
		})
	ProjectSettings.set_as_basic("player2/game_key", true)
	ProjectSettings.set_as_basic("player2/api", true)
	ProjectSettings.set_as_basic("player2/client_id", true)
	
func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	remove_custom_type("Player2AINPC")
	remove_custom_type("Player2STT")
	# Settings
	ProjectSettings.clear("player2/game_key")
	ProjectSettings.clear("player2/client_id")
	ProjectSettings.clear("player2/api")

func _enable_plugin() -> void:
	add_autoload_singleton(ASYNC_HELPER_AUTOLOAD_NAME, ASYNC_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(ERROR_HELPER_AUTOLOAD_NAME, ERROR_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(WEB_HELPER_AUTOLOAD_NAME, WEB_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(AUTH_HELPER_AUTOLOAD_NAME, AUTH_HELPER_AUTOLOAD_PATH)
	# add_autoload_singleton(API_HELPER_AUTOLOAD_NAME, API_HELPER_AUTOLOAD_PATH)

func _disable_plugin() -> void:
	remove_autoload_singleton(ASYNC_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(ERROR_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(WEB_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(AUTH_HELPER_AUTOLOAD_NAME)
	# remove_autoload_singleton(API_HELPER_AUTOLOAD_NAME)
