extends Node

# This is silly but yeah may as well do it right :tm:
class UrlPort:
	var url : String
	var port : int
	func _init(url : String, port : int):
		self.url = url
		self.port = port

# default port if none provided is -1 (let Godot handle this)
func _parse_url_and_port(path : String) -> UrlPort:
	var url = path
	var port = -1

	var port_index = path.rfind(":")
	if port_index != -1:
		url = path.substr(0, port_index)
		port = path.substr(port_index + 1).to_int()

	return UrlPort.new(url, port)

func request(path : String, method: HTTPClient.Method = HTTPClient.Method.METHOD_GET, body : Variant = "", headers : Array[String] = [], on_completed : Callable = Callable(), on_fail : Callable = Callable()) -> void:

	var string_body : String = body if body is String else JsonClassConverter.class_to_json_string(body)

	print("HTTP REQUEST:")
	print("\n\n")
	print(string_body)
	print("\n\n")

	# mock it
	#if on_completed:
		#on_completed.call('{"id":"","object":"chat.completion","created":10,"model":"","choices":[{"index":0,"message":{"role":"assistant","content":"```json\n{\n  \"reason\": \"The user has responded positively. I should ask how I can help them.\",\n  \"message\": \"Great! What can I do for you today, Potato?\",\n  \"function\": \"\",\n  \"args\": {}\n}\n```"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1088,"completion_tokens":59,"total_tokens":1147}}{ "id": "99deb1e8-97c3-439f-ae2b-347672e142dc", "object": "chat.completion", "created": 1751543344.0, "model": "elefant-ai-200b-fp8", "choices": [{ "index": 0.0, "message": { "role": "assistant", "content": "```json\n{\n  \"reason\": \"The user has responded positively. I should ask how I can help them.\",\n  \"message\": \"Great! What can I do for you today, Potato?\",\n  \"function\": \"\",\n  \"args\": {}\n}\n```" }, "finish_reason": "stop" }], "usage": { "prompt_tokens": 1088.0, "completion_tokens": 59.0, "total_tokens": 1147.0 } }', 200)
		#on_completed.call('{"choices": [{"finish_reason": "tool_calls","index": 0,"message": {"content": "","role": "assistant","tool_calls": [{"function": {"arguments": "{}","name": "blink"},"id": "tool_call_25bdd34724c0","type": "function"}]}}],"created": 1751055674,"id": "62df2ff4-fb24-4e2e-9ed9-0a261c5033f1","model": "elefant-ai-200b-fp8","object": "chat.completion","usage": {"completion_tokens": 6,"prompt_tokens": 628,"total_tokens": 634}}', 200)
		#on_completed.call('{"choices":[{"message":{"content":"","tool_calls":[{"function":{"arguments":"{}\n","name":"blink"},"id":"","type":""}]}}]}', 200)
		#on_completed.call('{ "choices": [{ "finish_reason": "stop", "index": 0.0, "message": { "content": "```json\n{\n  \"reason\": \"The user asked me to blink the screen. I will call the blink function.\",\n  \"message\": \"Sure, I can do that!\",\n  \"function\": \"blink\",\n  \"args\": {}\n}\n```", "role": "assistant" } }], "created": 1751056169.0, "id": "cd5a3180-5d08-4a3d-9274-5693f15657f7", "model": "elefant-ai-200b-fp8", "object": "chat.completion", "usage": { "completion_tokens": 57.0, "prompt_tokens": 654.0, "total_tokens": 711.0 } }', 200)
	#return

	var http = HTTPRequest.new()
	add_child(http)

	var on_completed_inner : Callable
	on_completed_inner = func(result, response_code, headers, body):
		print("HTTP done")
		if result != HTTPRequest.RESULT_SUCCESS:
			if on_fail != null:
				on_fail.call(result)
		else:
			if on_completed:
				on_completed.call(body.get_string_from_utf8() if body else "", response_code)
		#if on_completed_inner != null:
			#http.request_completed.disconnect(on_completed_inner)
		remove_child(http)
		http.queue_free()
	http.request_completed.connect(on_completed_inner)

	var err = http.request(path, headers, method, string_body)

	if err != OK:
		print("Error sending HTTP request")
		print(err)
		if on_fail != null:
			on_fail.call(err)
		return

func call_timeout(call : Callable, timeout : float) -> void:
	var t = Timer.new()
	t.autostart = false
	t.timeout.connect(func():
		call.call()
		t.queue_free())
	add_child(t)
	t.start(timeout)
	pass
