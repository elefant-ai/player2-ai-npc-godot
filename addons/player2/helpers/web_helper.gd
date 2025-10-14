@tool
extends Node

var should_print_response = func(path : String, body : String): return true

func _body_to_string(body : Variant) -> String:
	if body is String:
		return body
	elif body is Dictionary:
		return JSON.stringify(body)
	return JsonClassConverter.class_to_json_string(body)


func request(path : String, method: HTTPClient.Method = HTTPClient.Method.METHOD_GET, body : Variant = "", headers : Array[String] = [], on_completed : Callable = Callable(), on_fail : Callable = Callable(), timeout = -1) -> void:
	var string_body := _body_to_string(body)

	print("HTTP REQUEST:")
	print(headers)
	print(string_body)
	print("\n")
	# print_stack()

	# mock it
	#if on_completed:
		#on_completed.call('{"id":"","object":"chat.completion","created":10,"model":"","choices":[{"index":0,"message":{"role":"assistant","content":"```json\n{\n  \"reason\": \"The user has responded positively. I should ask how I can help them.\",\n  \"message\": \"Great! What can I do for you today, Potato?\",\n  \"function\": \"\",\n  \"args\": {}\n}\n```"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1088,"completion_tokens":59,"total_tokens":1147}}{ "id": "99deb1e8-97c3-439f-ae2b-347672e142dc", "object": "chat.completion", "created": 1751543344.0, "model": "elefant-ai-200b-fp8", "choices": [{ "index": 0.0, "message": { "role": "assistant", "content": "```json\n{\n  \"reason\": \"The user has responded positively. I should ask how I can help them.\",\n  \"message\": \"Great! What can I do for you today, Potato?\",\n  \"function\": \"\",\n  \"args\": {}\n}\n```" }, "finish_reason": "stop" }], "usage": { "prompt_tokens": 1088.0, "completion_tokens": 59.0, "total_tokens": 1147.0 } }', 200)
		#on_completed.call('{"choices": [{"finish_reason": "tool_calls","index": 0,"message": {"content": "","role": "assistant","tool_calls": [{"function": {"arguments": "{}","name": "blink"},"id": "tool_call_25bdd34724c0","type": "function"}]}}],"created": 1751055674,"id": "62df2ff4-fb24-4e2e-9ed9-0a261c5033f1","model": "elefant-ai-200b-fp8","object": "chat.completion","usage": {"completion_tokens": 6,"prompt_tokens": 628,"total_tokens": 634}}', 200)
		#on_completed.call('{"choices":[{"message":{"content":"","tool_calls":[{"function":{"arguments":"{}\n","name":"blink"},"id":"","type":""}]}}]}', 200)
		#on_completed.call('{ "choices": [{ "finish_reason": "stop", "index": 0.0, "message": { "content": "```json\n{\n  \"reason\": \"The user asked me to blink the screen. I will call the blink function.\",\n  \"message\": \"Sure, I can do that!\",\n  \"function\": \"blink\",\n  \"args\": {}\n}\n```", "role": "assistant" } }], "created": 1751056169.0, "id": "cd5a3180-5d08-4a3d-9274-5693f15657f7", "model": "elefant-ai-200b-fp8", "object": "chat.completion", "usage": { "completion_tokens": 57.0, "prompt_tokens": 654.0, "total_tokens": 711.0 } }', 200)
	#return

	var http := HTTPRequest.new()
	add_child(http)

	# Fix for web build to work
	http.accept_gzip = false

	http.timeout = timeout if timeout != -1 else Player2APIConfig.grab().request_timeout

	var on_completed_inner : Callable
	on_completed_inner = func(result, response_code, headers, body):
		if result != HTTPRequest.RESULT_SUCCESS:
			print("Godot HTTP failure: ", result)
			if on_fail:
				on_fail.call(result, response_code)
		else:
			print("HTTP success:", path,"=", response_code)
			var should_print_response = should_print_response.call(path, body.get_string_from_utf8())
			if should_print_response:
				print(body.get_string_from_utf8())
			else:
				print("(body omitted)")
			if response_code == 429:
				# Too many requests, try again...
				print("too many requests, trying again...")
				Player2AsyncHelper.call_timeout(
					func():
						# Call ourselves again...
						request(path, method, body, headers, on_completed, on_fail, timeout),
					Player2APIConfig.grab().retry_delay
				)
				return
			if on_completed:
				on_completed.call(body.get_string_from_utf8() if body else "", response_code, headers)
		#if on_completed_inner != null:
			#http.request_completed.disconnect(on_completed_inner)
		remove_child(http)
		http.queue_free()
	http.request_completed.connect(on_completed_inner)

	var err = http.request(path, headers, method, string_body)

	if err != OK:
		print("Error sending HTTP request for ", path, ", headers=", headers, ", method=", method, ", body=", string_body)
		print(err)
		if on_fail != null:
			on_fail.call("Error sending HTTP request with the following Godot HTTP Error Code: ", err)
		return

func request_stream(host : String, port : int, path : String, method: HTTPClient.Method = HTTPClient.Method.METHOD_GET, body : Variant = "", headers : Array[String] = [], on_data : Callable = Callable(), on_completed : Callable = Callable(), on_fail : Callable = Callable(), timeout = -1):
	var string_body := _body_to_string(body)

	var http_client = HTTPClient.new()

	var connect_err := http_client.connect_to_host(host, port )
	if connect_err != OK:
		if on_fail:
			on_fail.call("Failed to connect to host (" + host + ":" + str(port) + "): " + str(connect_err), connect_err)
		return
	# Wait until resolved and connected.
	print("Connecting...")
	while http_client.get_status() == HTTPClient.STATUS_CONNECTING or http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		http_client.poll()
		await get_tree().process_frame
	# Request the public data of my own profile
	var req_err := http_client.request(method, path, headers, string_body)
	if req_err != OK:
		if on_fail:
			on_fail.call("Failed to connect to path (" + path + " for " + host + ":" + str(port) + "): " + str(req_err), req_err)
		return

	print("Requesting...")
	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		# Keep polling for as long as the request is being processed.
		http_client.poll()
		await get_tree().process_frame

	# print("STREAMING ", connect_err, ", ", req_err, ": ", http_client.get_status())

	if http_client.has_response():
		while http_client.get_status() == HTTPClient.STATUS_BODY:
			# While there is body left to be read
			http_client.poll()

			var rb = PackedByteArray()

			# Get a chunk.
			var chunk = http_client.read_response_body_chunk()
			while chunk.size() != 0:
				# print("    Chunk: ", chunk.size())
				rb = rb + chunk
				chunk = http_client.read_response_body_chunk()

			if rb.size() != 0:
				var code := http_client.get_response_code()
				var headers_reply := http_client.get_response_headers_as_dictionary()
				# print("GOT: ", code, rb.size())
				if on_data:
					var keep_running : bool = on_data.call(rb, code, headers_reply)
					if not keep_running:
						print("(stream ABORTED)")
						break # on_data false = stop stream

			await get_tree().process_frame
		print(http_client.get_status())

	print("STREAM DONE")

	#http_client.free()
	if on_completed and on_completed.is_valid():
		on_completed.call()
