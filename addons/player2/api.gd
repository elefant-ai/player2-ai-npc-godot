class_name Player2API

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
	print("chat" + JsonClassConverter.class_to_json_string(request))
	
	run = func():
		Player2WebHelper.request(config.endpoint_chat, HTTPClient.Method.METHOD_POST, request, _get_headers(config),
		func(body, code):
			if code == 429:
				# Too many requests, try again...
				print("too many requests, trying again...")
				Player2WebHelper.call_timeout(run, config.request_too_much_delay_seconds)
				return
			if code != 200:
				print("chat fail!")
				print(code)
				on_fail.call(code)
				return
			print("GOT RESPONSE with code " + str(code))
			print(body)
			#var result = JsonClassConverter.json_to_class(Player2Schema.ChatCompletionResponse, JSON.parse_string(body))
			var result = JSON.parse_string(body)
			on_complete.call(result)
		,
		func(code):
			print("chat fail!")
			print(code)
			if on_fail:
				on_fail.call(code)
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

static func stt_start(config : Player2Config, request : Player2Schema.STTStartRequest, on_fail : Callable = Callable()) -> void:
	Player2WebHelper.request(config.endpoint_stt_start, HTTPClient.Method.METHOD_POST, request, _get_headers(config),
	Callable(),
	on_fail
	)

static func stt_stop(config : Player2Config, on_complete : Callable, on_fail : Callable = Callable()) -> void:
	Player2WebHelper.request(config.endpoint_stt_stop, HTTPClient.Method.METHOD_POST, "", _get_headers(config),
	func(body, code):
		if on_complete:
			on_complete.call(JSON.parse_string(body)),
	on_fail
	)

static func get_selected_characters(config : Player2Config, on_complete : Callable, on_fail : Callable = Callable()) -> void:
	Player2WebHelper.request(config.endpoint_get_selected_characters, HTTPClient.Method.METHOD_GET, "", _get_headers(config),
	func(body, code):
		on_complete.call(JSON.parse_string(body))
		,
	on_fail
	)
