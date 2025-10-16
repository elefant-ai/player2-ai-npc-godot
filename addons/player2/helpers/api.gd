@tool
extends Node

# auth: TODO: move? or not?
var _web_p2_key : String = ""
# Assume both are present, then fail if they're missing
var _last_local_present : bool = true
var _last_web_present : bool = true
var _source_tested : bool = false
var _source_testing : bool = false
## whether localhost:XXXX/login/web/{client_id} is assumed to exist
var _auth_local_endpoint_present : bool = true

## Emits when a request completes successfully
signal request_success(path : String)

# Queued up calls for auth
var _auth_running : bool = false
class RequestCallback:
	var run: Callable
	var on_fail : Callable
var _auth_queue : Array[RequestCallback] = []

var _internal_site : bool = false

func using_internal_site() -> bool:
	return _internal_site

func using_web() -> bool:
	var api = Player2APIConfig.grab()

	if api.source_mode == Player2APIConfig.SourceMode.WEB_ONLY:
		return true
	if api.source_mode == Player2APIConfig.SourceMode.LOCAL_ONLY:
		return false
	return _last_web_present

## Is a connection established to the API?
func established_api_connection() -> bool:
	return _source_tested

var _establishing_connection = false
var _establishing_connection_queue : Array[Callable] = []
## Ensure a connection to the API is established and have a callback for when the connection is complete.
## This is not necessary unless you wish to use something like STT
func establish_connection(on_complete : Callable = Callable()) -> void:
	if _establishing_connection:
		_establishing_connection_queue.push_back(on_complete)
		return
	var complete = func():
		for c in _establishing_connection_queue:
			if c.is_valid():
				c.call()
		if on_complete and on_complete.is_valid():
			on_complete.call()
		_establishing_connection_queue = []

	_establishing_connection = true
	# TODO: This can fail!
	if established_api_connection():
		_establishing_connection = false
		if complete.is_valid():
			complete.call()
		return
	# TODO: wrap the logic below in _req here to avoid an extra request
	get_health(
		func(data):
			_establishing_connection = false
			if complete.is_valid():
				complete.call()
			return,
		func(msg, code):
			_establishing_connection = false
			if complete.is_valid():
				complete.call()
			return,
	)

func _maybe_save_key():
	if _internal_site:
		return
	var api = Player2APIConfig.grab()
	if api.auth_key_cache_locally and _web_p2_key != "":
		_save_key(_web_p2_key)


## Save the auth key with some local encryption
func _save_key(key : String) -> void:
	var filename = "user://auth_cache"

	var client_id = ProjectSettings.get_setting("player2/client_id")
	if !client_id:
		client_id = ""

	var file = FileAccess.open(filename, FileAccess.WRITE)
	file.store_string(Player2CrappyEncryption.encrypt_unsecure("KEY: " + key, client_id))
	file.close()

## Load the auth key with some local encryption
func _load_key() -> String:
	var filename = "user://auth_cache"

	var client_id = ProjectSettings.get_setting("player2/client_id")
	if !client_id:
		client_id = ""


	if not FileAccess.file_exists(filename):
		return ""

	var file = FileAccess.open(filename, FileAccess.READ)

	var content := file.get_as_text()
	file.close()

	# Get decryption, validate that it works though
	var result = Player2CrappyEncryption.decrypt_unsecure(content, client_id)
	if result.begins_with("KEY: "):
		return result.substr("KEY: ".length())

	return ""

func _wipe_cached_key() -> void:
	var filename = "user://auth_cache"
	DirAccess.remove_absolute(filename)

func _get_headers(web : bool, accept_type : String = "application/json") -> Array[String]:
	var config := Player2APIConfig.grab()
	var result : Array[String] = [
		"Content-Type: application/json; charset=utf-8",
		"Accept: " + accept_type + "; charset=utf-8"
	]

	if web and !_web_p2_key.is_empty() and not _internal_site:
		result.push_back("Authorization: Bearer " + _web_p2_key)

	return result

func _code_success(code : int) -> bool:
	return 200 <= code and code < 300

# Run source test and call after a source has been established
# If a web is required, establish a connection somehow (get player to open up the auth page)
func _req(path_property : String, method: HTTPClient.Method = HTTPClient.Method.METHOD_GET, body : Variant = "", on_completed : Callable = Callable(), on_fail : Callable = Callable()):
	print("pre:", path_property)

	var api := Player2APIConfig.grab()
	var use_web = using_web()
	var endpoint = api.endpoint_web if use_web else api.endpoint_local
	var path = endpoint.path(path_property)

	print("hitting path ", path)
	
	var on_auth_ready = func(run_again):
		Player2WebHelper.request(
			path,
			method,
			body,
			_get_headers(use_web),
			# RECEIVE
			func(body, code, headers):
				# Check if successful HTTP
				if !_code_success(code):
					# not success
					# Unauthorized
					if use_web and code == 401:
						if _internal_site:
							Player2ErrorHelper.send_error("Got Unauthorized response. Try refreshing the page!")
							return
						print("Unauthorized response. Resetting key and trying to re-auth.")
						Player2ErrorHelper.send_error("Got Unauthorized while doing web requests, redoing auth.")
						_web_p2_key = ""
						run_again.call()
						return

					_alert_error_fail(code, false, body)
					if on_fail and on_fail.is_valid():
						on_fail.call(body, code)
					return
				if on_completed and on_completed.is_valid():
					# Try json, otherwise just return it...
					var result = JSON.parse_string(body)
					on_completed.call(result if result else body)
				request_success.emit(path_property)
				,
			# FAIL
			func(body, code):
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
				_alert_error_fail(code, true)
				if on_fail and on_fail.is_valid():
					on_fail.call("", code)
		)

	# Run the auth
	_prereq_auth(on_auth_ready, on_fail)

func _req_stream(path_property : String, method: HTTPClient.Method = HTTPClient.Method.METHOD_GET, body : Variant = "", on_data : Callable = Callable(), on_completed : Callable = Callable(), on_fail : Callable = Callable()):
	print("pre:", path_property)

	var api := Player2APIConfig.grab()
	var use_web = using_web()
	var endpoint = api.endpoint_web if use_web else api.endpoint_local

	# We need the host/port/path separately.
	# SUPER JANK: If the root does not match, it does not work.
	# Oh well.
	var root_full : String = endpoint.get("root")
	var last_colon := root_full.rfind(":")
	var host = root_full
	var port : int = -1
	if last_colon != -1:
		host = root_full.substr(0, last_colon)
		if host != "https" and host != "http":
			port = int(root_full.substr(last_colon + 1))
		else:
			host = root_full
	var path = endpoint.path_raw(path_property)

	print("hitting http stream: ", host, ":", port, "", path)

	# BIG CODE DUPLICATION HERE oh well
	var on_auth_ready = func(run_again):
		Player2WebHelper.request_stream(
			host, port, path,
			method,
			body,
			_get_headers(use_web, "application/octet-stream"),
			# RECEIVE DATA
			func(body, code, headers):
				# Check if successful HTTP
				if !_code_success(code):
					# not success
					# Unauthorized
					if use_web and code == 401:
						if _internal_site:
							Player2ErrorHelper.send_error("Got Unauthorized response. Try refreshing the page!")
							return
						print("Unauthorized response. Resetting key and trying to re-auth.")
						Player2ErrorHelper.send_error("Got Unauthorized while doing web requests, redoing auth.")
						_web_p2_key = ""
						run_again.call()
						return false

					_alert_error_fail(code, false, body)
					if on_fail and on_fail.is_valid():
						on_fail.call(body, code)
					print("(code failed: ", code, ")")
					return false
				if on_data and on_data.is_valid():
					# Try json, otherwise just return it...
					#var result = JSON.parse_string(body)
					var continue_stream = on_data.call(body)
					request_success.emit(path_property)
					return continue_stream
				return true,
			on_completed,
			# FAIL
			func(body, code):
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
				_alert_error_fail(code, true)
				if on_fail and on_fail.is_valid():
					on_fail.call("", code)
		)

	# Run the auth
	_prereq_auth(on_auth_ready, on_fail)	

func _prereq_auth(on_auth_ready : Callable, on_fail : Callable = Callable()):
	var api := Player2APIConfig.grab()

	# Some pre config
	if api.source_mode == Player2APIConfig.SourceMode.WEB_ONLY:
		_last_local_present = false
	if api.source_mode == Player2APIConfig.SourceMode.LOCAL_ONLY:
		_last_web_present = false

	var use_web = using_web()

	var run_again = func():
		_prereq_auth(on_auth_ready, on_fail)

	if !_source_tested and _source_testing:
		print("(tried a request while testing source, calling again later...)")
		# Just wait, keep it simple
		Player2AsyncHelper.call_timeout(run_again, 1)
		return

	if _auth_running:
		print("(tried a request while waiting for auth, queuing up...)")
		# Add self to auth queue
		var queued := RequestCallback.new()
		queued.run = run_again
		queued.on_fail = on_fail
		_auth_queue.push_back(queued)
		return

	var do_source_test_complete = func():
		_source_testing = false
		run_again.call()


	if !api:
		print("API config is null/not configured!")
		Player2ErrorHelper.send_error("API config is null/not configured. Problem!")
		assert(false)

	# Source is TESTED, proceed
	var endpoint = api.endpoint_web if use_web else api.endpoint_local

	# If not source tested...
	if !_source_tested:
		_source_testing = true
		var endpoint_check_url = endpoint.path("endpoint_check")

		var try_again_if_check_failed = func(double_failure : bool):
			_source_testing = false
			if double_failure:
				Player2ErrorHelper.send_error("Unable to connect to API. Will attempt to reconnect for a bit")
				# Wait a bit and go again if we have tried both and failed
				# TODO: Magic number
				Player2AsyncHelper.call_timeout(run_again, 3)
			elif run_again.is_valid():
				# Just go immediately
				run_again.call()

		# Both require some kind of short timeout check
		if use_web:
			print("confirming source with the web")
			# Web
			Player2WebHelper.request(
				endpoint_check_url,
				HTTPClient.Method.METHOD_GET,
				"",
				_get_headers(false),
				func(body, code, headers):
					print("web source confirmed! proceeding with web.")
					# We succeeded! pretend like this is normal and move on.
					_source_tested = true
					_last_web_present = true
					do_source_test_complete.call()
					,
				func(body, code):
					# Web failed!
					var was_assumed_present = _last_web_present and !_last_local_present
					_last_web_present = false
					if api.source_mode == Player2APIConfig.SourceMode.WEB_FIRST_THEN_LOCAL:
						# Try web again
						_last_local_present = true
					# Try again!
					print("Tried finding web API but failed. Retrying...")
					try_again_if_check_failed.call(was_assumed_present),
				api.request_timeout_check_web
			)
		else:
			print("confirming source with local")
			Player2WebHelper.request(
				endpoint_check_url,
				HTTPClient.Method.METHOD_GET,
				"",
				_get_headers(false),
				func(body, code, headers):
					# We succeeded! pretend like this is normal and move on.
					print("local source confirmed! proceeding with web.")
					_source_tested = true
					_last_local_present = true
					do_source_test_complete.call()
					,
				func(body, code):
					# Local failed!
					var was_assumed_present = _last_local_present and !_last_web_present
					_last_local_present = false
					if api.source_mode == Player2APIConfig.SourceMode.WEB_FIRST_THEN_LOCAL:
						# Try web again
						_last_web_present = true
					# Try again!
					print("Tried finding local API but failed. Retrying...")
					try_again_if_check_failed.call(was_assumed_present),
				api.request_timeout_check_local
			)
		# do NOT continue running the request, we are doing our thing up here.
		return

	# Check for auth key
	if use_web and _web_p2_key.is_empty() and not _internal_site:
		# No p2 auth key, run the auth sequence
		_auth_running = true

		var client_id = ProjectSettings.get_setting("player2/client_id")
		if !client_id:
			client_id = ""

		# TODO: Better way to get client id?

		if !client_id or client_id.is_empty():
			var msg = "No client id defined. Please set a valid client id in the project settings under player2/client_id"
			Player2ErrorHelper.send_error(msg)
			# TODO: Custom code/constant of some sorts?
			if on_fail and on_fail.is_valid():
				on_fail.call(msg, -2)
			return

		# When we complete auth successfully
		var do_auth_complete = func(p2_key : String):
			print("Successfully got auth key. Continuing to request.")
			_web_p2_key = p2_key
			_maybe_save_key()
			_auth_running = false
			# Auth completed: call everything in the queue
			run_again.call()
			var calls : Array[Callable] = []
			calls.assign(_auth_queue.map(func(c): return c.run))
			_auth_queue.clear()
			for c in calls:
				if c and c.is_valid():
					c.call()

		# The user can cancel the process at any time with Player2AuthHelper.cancel_auth()
		Player2AuthHelper.auth_user_cancelled.connect(
			func():
				_auth_running = false
				var msg = "Unable to connect to web after player denied auth request."
				Player2ErrorHelper.send_error(msg)
				# TODO: Custom code/constant of some sorts?
				if on_fail and on_fail.is_valid():
					on_fail.call(msg, -3)
				var calls : Array[Callable] = []
				calls.assign(_auth_queue.map(func(c): return c.on_fail))
				_auth_queue.clear()
				for c in calls:
					if c and c.is_valid():
						c.call(msg, -3)
		)

		# TRY auth local endpoint FIRST
		if _auth_local_endpoint_present and _last_local_present:
			# do NOT continue running the request, we are doing our thing up here.
			var local_auth_path = api.endpoint_local.path("webapi_login")
			local_auth_path = local_auth_path.replace("{client_id}", client_id)
			print("trying local auth first at ", local_auth_path)
			Player2WebHelper.request(
				local_auth_path,
				HTTPClient.Method.METHOD_POST,
				"",
				_get_headers(false),
				func(body, code, headers):
					_auth_running = false
					if Player2AuthHelper.auth_cancelled:
						return
					print("Got local auth response: ", body)
					if _code_success(code):
						var p2_key = JSON.parse_string(body)["p2Key"]
						do_auth_complete.call(p2_key)
					else:
						# Failure
						print("Local app auth failed, defaulting to web auth.")
						_auth_local_endpoint_present = false
						Player2AsyncHelper.call_timeout(run_again, 0.1)
					,
				func(body, code):
					_auth_running = false
					print("Local app auth failed, defaulting to web auth.")
					_auth_local_endpoint_present = false
					Player2AsyncHelper.call_timeout(run_again, 0.1)
					,
				api.request_timeout_local_auth
			)
			return

		# Begin validation
		var verify_begin_req := Player2Schema.AuthStartRequest.new()
		verify_begin_req.client_id = client_id
		print("Beginning auth")
		Player2WebHelper.request(
			api.endpoint_web.path("auth_start"),
			HTTPClient.Method.METHOD_POST,
			verify_begin_req,
			_get_headers(false),
			func(body, code, headers):
				print("Got auth start response: ", body)
				if Player2AuthHelper.auth_cancelled:
					return
				if _code_success(code):
					# Success. We got auth info.
					var result = JSON.parse_string(body)
					var verification_url = result["verificationUriComplete"]
					var device_code = result["deviceCode"]
					var user_code = result["userCode"]
					var expires_in = result["expiresIn"]
					var interval = result["interval"]
					var start_time_ms = Time.get_ticks_msec()
					
					var poll_req := Player2Schema.AuthPollRequest.new()
					poll_req.client_id = client_id
					poll_req.device_code = device_code
					poll_req.grant_type = "urn:ietf:params:oauth:grant-type:device_code"

					# Start the auth verification from the verifier
					var let_ui_know_auth_completed = Player2AuthHelper._run_auth_verification(verification_url)

					# Poll until we get it
					Player2AsyncHelper.call_poll(
						func(on_complete):
							if Player2AuthHelper.auth_cancelled:
								return
							Player2WebHelper.request(
								api.endpoint_web.path("auth_poll"),
								HTTPClient.Method.METHOD_POST,
								poll_req,
								_get_headers(false),
								func(body, code, headers):
									print("Got auth poll response: ", body)
									if Player2AuthHelper.auth_cancelled:
										return
									if _code_success(code):
										# We succeeded!
										if let_ui_know_auth_completed and let_ui_know_auth_completed.is_valid():
											let_ui_know_auth_completed.call()
										if on_complete.is_valid():
											on_complete.call(false)
										var p2_key = JSON.parse_string(body)["p2Key"]
										do_auth_complete.call(p2_key)
										return
									# we did NOT succeed
									# Check for expiration
									var delta_time_s = (Time.get_ticks_msec() - start_time_ms) / 1000
									var expired = expires_in and delta_time_s > expires_in
									if expired:
										print("Device code expired. Trying from the start...")
										Player2AsyncHelper.call_timeout(run_again, 2)
										if on_complete.is_valid():
											on_complete.call(false)
										return
									print("Got " + str(code) + " (polling)")
									if code != 400:
										Player2ErrorHelper.send_error("Auth polling Error " + str(code) + ": " + body)

									if on_complete.is_valid():
										on_complete.call(true),
								func(body, code):
									_auth_running = false
									# Fail while polling
									Player2ErrorHelper.send_error("Unable to connect to web during auth polling. Trying from start...")
									Player2AsyncHelper.call_timeout(run_again, 2)
									if on_complete.is_valid():
										on_complete.call(false)
									pass
							)
							,
						interval if interval else 2
					)
				else:
					# HTTP Failure for auth start
					Player2ErrorHelper.send_error("Auth endpoint Error code: " + str(code) + ": " + body)
				,
			func(body, code):
				# fail auth start
				Player2ErrorHelper.send_error("Unable to connect to web for auth. Trying again... " + str(code))
				Player2AsyncHelper.call_timeout(run_again, 2)
				pass
		)
		# do NOT continue running the request, we are doing our thing up here.
		return

	if on_auth_ready.is_valid():
		on_auth_ready.call(run_again)


func _alert_error_fail(code : int, use_http_result : bool = false, response_body : String = ""):
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
			Player2ErrorHelper.send_error("User is not authenticated: " + response_body)
		402:
			Player2ErrorHelper.send_error("Insufficient credits to complete request: " + response_body)
		403:
			Player2ErrorHelper.send_error("Forbidden: " + response_body)
		500:
			Player2ErrorHelper.send_error("Internal server error: " + response_body)


func get_health(on_complete : Callable = Callable(), on_fail : Callable = Callable()):
	_req("health", HTTPClient.Method.METHOD_GET, "",
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
	# also default response format if none specified
	if !request.response_format or request.response_format.size() == 0:
		json_req.erase("response_format")

	_req("chat", HTTPClient.Method.METHOD_POST, json_req,
		on_complete, on_fail
	)

func _filter_tts_req(request : Player2Schema.TTSRequest) -> Dictionary:
	var json_req = JsonClassConverter.class_to_json(request)
	if !request.advanced_voice or request.advanced_voice.instructions.is_empty():
		json_req.erase("advanced_voice")
	return json_req

func tts_speak(request : Player2Schema.TTSRequest, on_complete : Callable = Callable(), on_fail : Callable = Callable()) -> void:
	_req("tts_speak", HTTPClient.Method.METHOD_POST, _filter_tts_req(request), on_complete, on_fail)

func tts_speak_stream(request : Player2Schema.TTSRequest, on_data : Callable, on_complete : Callable = Callable(), on_fail : Callable = Callable()) -> void:
	_req_stream("tts_speak_stream", HTTPClient.Method.METHOD_POST, _filter_tts_req(request), on_data, on_complete, on_fail)

func tts_stop(on_fail : Callable = Callable()) -> void:
	_req("tts_stop", HTTPClient.Method.METHOD_POST, "", Callable(), on_fail)

func stt_start(request : Player2Schema.STTStartRequest, on_fail : Callable = Callable()) -> void:
	_req("stt_start", HTTPClient.Method.METHOD_POST, "", Callable(), on_fail)

func stt_stop(on_complete : Callable, on_fail : Callable = Callable()) -> void:
	_req("stt_stop", HTTPClient.Method.METHOD_POST, "", on_complete, on_fail)

func joules(on_complete : Callable, on_fail : Callable = Callable()) -> void:
	_req("joules", HTTPClient.Method.METHOD_GET, "", on_complete, on_fail)

func get_selected_characters(on_complete : Callable, on_fail : Callable = Callable()) -> void:
	_req("get_selected_characters", HTTPClient.Method.METHOD_GET, "", on_complete, on_fail)

func image_generate(request : Player2Schema.ImageGenerateRequest, on_complete : Callable, on_fail : Callable = Callable()) -> void:
	_req("image_generate", HTTPClient.Method.METHOD_POST, request, on_complete, on_fail)

func stt_stream_socket(sample_rate : int = 44100) -> WebSocketPeer:

	if not established_api_connection():
		printerr("Tried stt socket streaming but no API connection is established")
		return null

	var api = Player2APIConfig.grab()

	# Construct the URL
	var endpoint = api.endpoint_web
	var url = endpoint.path("stt_stream")
	var stream_protocol = api.endpoint_web.stt_protocol
	if url.begins_with("https://"):
		url = stream_protocol + "://" + url.substr("https://".length())
	if url.begins_with("http://"):
		url = stream_protocol + "://" + url.substr("http://".length())
		
	var params := {
		#"model": "nova-2", # TODO: Drop this?
		"language": "en-US", # TODO: Configure
		"encoding": "linear16",
		"sample_rate": sample_rate,
		"interim_results": true
	}
	if not _internal_site:
		params["token"] = _web_p2_key

	var http_params = "&".join(params.keys().map(func(k): return k+"="+str(params[k]).uri_encode()))
	
	var full_url = url
	if not http_params.is_empty():
		full_url += "?" + http_params

	var socket = WebSocketPeer.new()

	print("HTTP Socket: ", full_url)

	var conn_err = socket.connect_to_url(full_url)
	if conn_err != OK:
		print("FAILED TO CONNECT TO SOCKET")
		return null
	return socket

func _ready() -> void:

	# Don't print TTS responses, they are big!
	var api = Player2APIConfig.grab()

	Player2WebHelper.should_print_response = func(path : String, body : String):
		# keep editor tooling clean for now...
		if Engine.is_editor_hint():
			return
		if path == api.endpoint_web.path("tts_speak") or path == api.endpoint_local.path("tts_speak"):
			return false
		return true

	if Engine.is_editor_hint():
		return

	# Check for internal site
	if Engine.has_singleton("JavaScriptBridge"):
		var origin = JavaScriptBridge.eval("window.location.origin", true)
		if origin is String and origin.ends_with(api.endpoint_web.internal_site_origin):
			# We are in the internal site. OVERRIDE
			print("Found that we're in the internal site. Forcing web and not doing any auth since the site handles that for us!")
			_internal_site = true
			api.source_mode = Player2APIConfig.SourceMode.WEB_ONLY
			api.endpoint_web.set_using_site(origin)


	var client_id = ProjectSettings.get_setting("player2/client_id")
	if !client_id:
		client_id = ""

	if !client_id or client_id.is_empty():
		var msg = "No client id defined. Please set a valid client id in the project settings under player2/client_id"
		Player2ErrorHelper.send_error(msg)

	# Before we start, load our key.
	if api.auth_key_cache_locally and _web_p2_key == "" and not _internal_site:
		_web_p2_key = _load_key()
		print("loading auth key: ", _web_p2_key)
		if _web_p2_key == "":
			print("No auth key found or failed. Making sure cache is empty now.")
			_wipe_cached_key()
	else:
		_wipe_cached_key()

	# Web Auth Prompt Immediately
	if api.prompt_auth_page_immediately:
		establish_connection()

	# Power hud
	if api.ui_power_hud:
		var power_hud : Node = api.ui_power_hud.instantiate()
		add_child(power_hud)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_maybe_save_key()
