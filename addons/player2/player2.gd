@tool
class_name Player2
extends EditorPlugin

const WEB_HELPER_AUTOLOAD_NAME = "Player2WebHelper"
const WEB_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/web_helper.gd"

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass

func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass

func _enable_plugin() -> void:
	add_autoload_singleton(WEB_HELPER_AUTOLOAD_NAME, WEB_HELPER_AUTOLOAD_PATH)

func _disable_plugin() -> void:
	remove_autoload_singleton(WEB_HELPER_AUTOLOAD_NAME)


static func chat(config : Player2Config, request: Player2Schema.ChatCompletionRequest, on_complete: Callable, on_fail: Callable = Callable()) -> void:
	Player2WebHelper.request(config.endpoint_chat, HTTPClient.Method.METHOD_POST, request,
	func(body, code):
		var result = JSON.parse_string(body) as Player2Schema.ChatCompletionResponse
		on_complete.call(result)
	,
	on_fail
	)

static func get_health(config : Player2Config, on_complete : Callable, on_fail : Callable = Callable()):
	Player2WebHelper.request(config.endpoint_health, HTTPClient.Method.METHOD_GET, "",
	func(body, code):
		var result = JsonClassConverter.json_to_class(Player2Schema.Health, JSON.parse_string(body))
		on_complete.call(result)
	,
	on_fail
	)
