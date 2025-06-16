@tool
class_name Player2
extends EditorPlugin

const WEB_HELPER_AUTOLOAD_NAME = "Player2WebHelper"
const WEB_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/web_helper.gd"

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	add_custom_type("Player2Agent", "Player2Agent", preload("agent.gd"), preload("p2.svg"))

func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	remove_custom_type("Player2Agent")

func _enable_plugin() -> void:
	add_autoload_singleton(WEB_HELPER_AUTOLOAD_NAME, WEB_HELPER_AUTOLOAD_PATH)

func _disable_plugin() -> void:
	remove_autoload_singleton(WEB_HELPER_AUTOLOAD_NAME)

static func _get_headers(config : Player2Config) -> Array[String]:
	return [
		"Content-Type: application/json; charset=utf-8",
		"Accept: application/json; charset=utf-8",
		"player2-game-key: " + config.player2_game_key
	]

static func get_health(config : Player2Config, on_complete : Callable, on_fail : Callable = Callable()):
	Player2WebHelper.request(config.endpoint_health, HTTPClient.Method.METHOD_GET, "", _get_headers(config),
	func(body, code):
		#var result = JsonClassConverter.json_to_class(Player2Schema.Health, JSON.parse_string(body))
		var result = JSON.parse_string(body)
		on_complete.call(result)
	,
	on_fail
	)

static func chat(config : Player2Config, request: Player2Schema.ChatCompletionRequest, on_complete: Callable, on_fail: Callable = Callable()) -> void:
	var run : Callable
	
	run = func():
		Player2WebHelper.request(config.endpoint_chat, HTTPClient.Method.METHOD_POST, request, _get_headers(config),
		func(body, code):
			if code == 429:
				# Too many requests, try again...
				print("too many requests, trying again...")
				Player2WebHelper.call_timeout(run, config.request_too_much_delay_seconds)
				return
			if code != 200:
				on_fail.call(code)
				return
			print("GOT RESPONSE with code " + str(code))
			print(body)
			#var result = JsonClassConverter.json_to_class(Player2Schema.ChatCompletionResponse, JSON.parse_string(body))
			var result = JSON.parse_string(body)
			on_complete.call(result)
		,
		on_fail
		)

	run.call()

static func tts_speak(config : Player2Config, request : Player2Schema.TTSRequest, on_fail : Callable = Callable()) -> void:
	Player2WebHelper.request(config.endpoint_tts_speak, HTTPClient.Method.METHOD_POST, request, _get_headers(config),
	Callable(),
	on_fail
	)

static func tts_stop(config : Player2Config, on_fail : Callable = Callable()) -> void:
	Player2WebHelper.request(config.endpoint_tts_stop, HTTPClient.Method.METHOD_POST, "", _get_headers(config),
	Callable(),
	on_fail
	)

static func get_selected_characters(config : Player2Config, on_complete : Callable, on_fail : Callable = Callable()) -> void:
	Player2WebHelper.request(config.endpoint_get_selected_characters, HTTPClient.Method.METHOD_GET, "", _get_headers(config),
	func(body, code):
		on_complete.call(JSON.parse_string(body))
		,
	on_fail
	)	
