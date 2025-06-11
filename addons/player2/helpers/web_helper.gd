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

	var string_body = body if body is String else JsonClassConverter.class_to_json_string(body)

	print("HTTP REQUEST:")
	print("\n\n")
	print(string_body)
	print("\n\n")
	# mock it
	#on_completed.call('{"choices":[{"message":{"content":"","tool_calls":[{"function":{"arguments":"{}\n","name":"blink"},"id":"","type":""}]}}]}', 200)
	#return
	#on_completed.call('{"choices":[{"message":{"content":"Hello! How can I help you today?\n"}}]}', 200)
	#return

	var http = HTTPRequest.new()
	add_child(http)

	var on_completed_inner : Callable
	on_completed_inner = func(result, response_code, headers, body):
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
