extends Node

# auth: TODO: move? or not?
var _web_p2_key : String = ""
# Assume both are present, then fail if they're missing
var _last_local_present : bool = true
var _last_web_present : bool = true
var _source_tested : bool = false

func using_web() -> bool:
	return !_last_local_present

func _get_headers(web : bool) -> Array[String]:
	var config := Player2APIConfig.grab()
	var game_key = ProjectSettings.get_setting("player2/game_key")
	if !game_key or game_key.is_empty():
		game_key = "undefined_godot_project"
	var key = game_key# game_key.replace(" ", "_").replace(":", "_")
	var result = [
		"Content-Type: application/json; charset=utf-8",
		"Accept: application/json; charset=utf-8",
		"player2-game-key: " + key
	]

	if web and !_web_p2_key.is_empty():
		result.push_back("Authorization: Bearer " + _web_p2_key)

	return result

func code_success(code : int) -> bool:
	return 200 <= code and code < 300

# Run source test and call after a source has been established
# If a web is required, establish a connection somehow (get player to open up the auth page)
func _req(path_property : String, method: HTTPClient.Method = HTTPClient.Method.METHOD_GET, body : Variant = "", on_completed : Callable = Callable(), on_fail : Callable = Callable()):

	var run_again = func():
		_req(path_property, method, body, on_completed, on_fail)

	# When we receive the results ..
	var receive_results = func(body, code, headers):
		# Check if successful HTTP
		if !code_success(code):
			# not success
			_alert_error_fail(code)
			if on_fail:
				on_fail.call(code)
			return
		if on_completed:
			# Try json, otherwise just return it...
			var result = JSON.parse_string(body)
			on_completed.call(result if result else body)
		

	var api := Player2APIConfig.grab()

	var use_web = using_web()

	# Source is TESTED, proceed
	var path = api.endpoint_web.get(path_property) if use_web else api.endpoint_local.get(path_property)

	# If not source tested...
	if !_source_tested:
		var endpoint_check_url = api.endpoint_web.endpoint_check if use_web else api.endpoint_local.endpoint_check

		var try_again_if_check_failed = func(was_expecting_success : bool):
			if !_last_local_present and !_last_web_present:
				if was_expecting_success:
					Player2ErrorHelper.send_error("Unable to connect to web OR local launcher. Will attempt to reconnect for a bit")
				# Wait a bit and go again if we have tried both and failed
				# TODO: Magic number
				Player2AsyncHelper.call_timeout(run_again, 3)
			else:
				# Just go immediately
				run_again.call()

		# If local, just try running.
		if use_web:
			# Web
			Player2WebHelper.request(
				endpoint_check_url,
				HTTPClient.Method.METHOD_GET,
				"",
				_get_headers(false),
				func(body, code, headers):
					# We succeeded! pretend like this is normal and move on.
					_source_tested = true
					_last_local_present = true
					receive_results.call(body, code, headers)
					,
				func(code):
					# Web failed!
					var was_assumed_present = _last_web_present
					_last_web_present = false
					# Try again!
					print("Tried finding web API but failed. Retrying...")
					try_again_if_check_failed.call(was_assumed_present)
			)
		else:
			# Local
			Player2WebHelper.request(path,
				method,
				body,
				_get_headers(false),
				func(body, code, headers):
					# We succeeded! pretend like this is normal and move on.
					_source_tested = true
					_last_local_present = true
					receive_results.call(body, code, headers)
					,
				func(code):
					# Local Failed!
					var was_assumed_present = _last_local_present
					_last_local_present = false
					# Try again!
					print("Tried finding local API but failed. Retrying...")
					try_again_if_check_failed.call(was_assumed_present)
			)
	# do NOT continue running the request, we are doing our thing up here.
	return

	# Check for auth key
	if use_web and _web_p2_key:
		# No p2 auth key, run the auth sequence
		# TODO: Better way to get client id?
		var client_id = ProjectSettings.get_setting("player2/client_id")

		# The user can cancel the process at any time with Player2AuthHelper.cancel_auth()
		var auth_cancelled = false
		Player2AuthHelper.auth_cancelled.connect(func():
			if !auth_cancelled:
				print("Player cancelled auth request. Dropping and failing.")
				Player2ErrorHelper.send_error("Unable to connect to web after player deined auth request.")
				# TODO: Custom code/constant of some sorts?
				on_fail.call(-2)
				auth_cancelled = true
		)

		# Begin validation
		var verify_begin_req := Player2Schema.AuthStartRequest.new()
		verify_begin_req.client_id = client_id
		Player2WebHelper.request(
			api.endpoint_web.auth_start,
			HTTPClient.Method.METHOD_POST,
			verify_begin_req,
			_get_headers(false),
			func(body, code, headers):
				if auth_cancelled:
					return
				if code_success(code):
					# Success. We got auth info.
					var result = JSON.parse_string(body)
					var verification_url = result["verificationUriComplete"]
					var device_code = result["deviceCode"]
					var user_code = result["userCode"]
					var expires_in = result["expiresIn"]
					var interval = result["interval"]
					var start_time_ms = Time.get_ticks_msec()
					# Poll until we get it
					Player2AsyncHelper.call_poll(
						func(on_complete):
							if auth_cancelled:
								return
							Player2WebHelper.request(
								api.endpoint_web.auth_poll,
								HTTPClient.Method.METHOD_POST,
								verify_begin_req,
								_get_headers(false),
								func(body, code, headers):
									if auth_cancelled:
										return
									if code_success(code):
										# We succeeded!
										print("Successfully got auth key. Continuing to request.")
										_web_p2_key =JSON.parse_string(body)["p2Key"]
										on_complete.call(false)
										run_again.call()
										return
									# we did NOT succeed
									# Check for expiration
									var delta_time_s = (Time.get_ticks_msec() - start_time_ms) / 1000
									var expired = expires_in and delta_time_s > expires_in
									if expired:
										print("Device code expired. Trying again...")
										Player2AsyncHelper.call_timeout(run_again, 2)
										on_complete.call(false)
										return
									print("Got " + str(code) + " (polling)")
									on_complete.call(true),
								func(code):
									# Fail while polling
									print("Connection failed. Trying again...")
									Player2ErrorHelper.send_error("Unable to connect to web during auth polling. Trying from start...")
									Player2AsyncHelper.call_timeout(run_again, 2)
									on_complete.call(false)
									pass
							)
							,
						interval if interval else 2
					)
				else:
					# HTTP Failure for auth start
					Player2ErrorHelper.send_error("Auth endpoint Error code: " + str(code))
				,
			func(code):
				# fail auth start
				Player2ErrorHelper.send_error("Unable to connect to web for auth. Trying again... " + str(code))
				Player2AsyncHelper.call_timeout(run_again, 2)
				pass
		)
		# do NOT continue running the request, we are doing our thing up here.
		return

	Player2WebHelper.request(
		path,
		method,
		body,
		_get_headers(use_web),
		receive_results,
		func(code):
			_alert_error_fail(code, true)

			# Failure, notify if local/web is present
			if code != HTTPRequest.RESULT_SUCCESS:
				if use_web:
					_last_web_present = false
				else:
					_last_local_present = false
				# both were tested, both failed.
				if !_last_local_present and !_last_web_present:
					_source_tested = false
					# Try finding the source again!
					print("Source got unset. Trying to find again...")
					# TODO: Magic number
					Player2AsyncHelper.call_timeout(run_again, 3)
			else:
				_last_web_present = true
			if on_fail:
				on_fail.call(code)
	)


func _alert_error_fail(code : int, use_http_result : bool = false):
	if use_http_result:
		match (code):
			HTTPRequest.RESULT_SUCCESS:
				return
			HTTPRequest.RESULT_CANT_CONNECT:
				Player2ErrorHelper.send_error("Cannot connect to the Player2 Launcher!")
			var other:
				Player2ErrorHelper.send_error("Godot HttpResult Error Code " + str(other))
				pass
	match (code):
		401:
			Player2ErrorHelper.send_error("User is not authenticated in the Player2 Launcher!")
		402:
			Player2ErrorHelper.send_error("Insufficient credits to complete request.")
		500:
			Player2ErrorHelper.send_error("Internal server error.")


func get_health(on_complete : Callable, on_fail : Callable = Callable()):
	_req("endpoint_health", HTTPClient.Method.METHOD_GET, "",
	on_complete,
	on_fail
	)

func chat(request: Player2Schema.ChatCompletionRequest, on_complete: Callable, on_fail: Callable = Callable()) -> void:

	# Conditionally REMOVE if there are no tools/tool choice
	var json_req = JsonClassConverter.class_to_json(request)
	if !request.tools or request.tools.size() == 0:
		json_req.erase("tools")
		json_req.erase("tool_choice")
		for m : Dictionary in json_req["messages"]:
			m.erase("tool_call_id")
			m.erase("tool_calls")

	_req("endpoint_chat", HTTPClient.Method.METHOD_POST, json_req,
		on_complete, on_fail
	)

func tts_speak(request : Player2Schema.TTSRequest,on_complete : Callable = Callable(), on_fail : Callable = Callable()) -> void:
	_req("endpoint_tts_speak", HTTPClient.Method.METHOD_POST, request, on_complete, on_fail)

func tts_stop(on_fail : Callable = Callable()) -> void:
	_req("endpoint_tts_stop", HTTPClient.Method.METHOD_POST, "", Callable(), on_fail)

func stt_start(request : Player2Schema.STTStartRequest, on_fail : Callable = Callable()) -> void:
	_req("endpoint_stt_start", HTTPClient.Method.METHOD_POST, "", Callable(), on_fail)

func stt_stop(on_complete : Callable, on_fail : Callable = Callable()) -> void:
	_req("endpoint_stt_stop", HTTPClient.Method.METHOD_POST, "", on_complete, on_fail)

func get_selected_characters(on_complete : Callable, on_fail : Callable = Callable()) -> void:
	_req("endpoint_get_selected_characters", HTTPClient.Method.METHOD_GET, "", on_complete, on_fail)
