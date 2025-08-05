@tool
class_name Player2
extends EditorPlugin

const WEB_HELPER_AUTOLOAD_NAME = "Player2WebHelper"
const WEB_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/web_helper.gd"

const ERROR_HELPER_AUTOLOAD_NAME = "Player2ErrorHelper"
const ERROR_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/error_helper.tscn"

const ASYNC_HELPER_AUTOLOAD_NAME = "Player2AsyncHelper"
const ASYNC_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/async_helper.gd"

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	add_custom_type("Player2AINPC", "Player2AINPC", preload("Player2AINPC.gd"), preload("p2.svg"))
	add_custom_type("Player2STT", "Player2STT", preload("Player2STT.gd"), preload("p2.svg"))
	# Settings
	if not ProjectSettings.has_setting("player2/game_key"):
		var default : String = ProjectSettings.get_setting("application/config/name")
		if !default:
			default = "my_game"
		default = default.replace(" ", "_").replace(":", "_")
		ProjectSettings.set_setting("player2/game_key", default)
		ProjectSettings.add_property_info({
			"name": "player2/game_key",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "The game key used "
		})
		ProjectSettings.set_as_basic("player2/game_key", true)

func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	remove_custom_type("Player2AINPC")
	remove_custom_type("Player2STT")
	# Settings
	ProjectSettings.clear("player2/game_key")

func _enable_plugin() -> void:
	add_autoload_singleton(WEB_HELPER_AUTOLOAD_NAME, WEB_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(ERROR_HELPER_AUTOLOAD_NAME, ERROR_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(ASYNC_HELPER_AUTOLOAD_NAME, ASYNC_HELPER_AUTOLOAD_PATH)

func _disable_plugin() -> void:
	remove_autoload_singleton(WEB_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(ERROR_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(ASYNC_HELPER_AUTOLOAD_NAME)
