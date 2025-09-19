extends Node

var http_client : HTTPClient
var streaming : bool

# I initialise the request
func _ready() -> void:
	http_client = HTTPClient.new()
	var connect_err := http_client.connect_to_host("http://127.0.0.1", 3000)
	assert(connect_err == OK)
	# Wait until resolved and connected.
	while http_client.get_status() == HTTPClient.STATUS_CONNECTING or http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		http_client.poll()
		print("Connecting...")
		await get_tree().process_frame
	# Request the public data of my own profile
	var req_err := http_client.request(HTTPClient.Method.METHOD_GET, "/stream", [])
	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		# Keep polling for as long as the request is being processed.
		http_client.poll()
		print("Requesting...")
		await get_tree().process_frame
	assert(req_err == OK)
	streaming = true
	print("STREAMING ", connect_err, ", ", req_err, ": ", http_client.get_status())
	
	if http_client.has_response():
		while http_client.get_status() == HTTPClient.STATUS_BODY:
			# While there is body left to be read
			http_client.poll()
			# Get a chunk.
			var chunk = http_client.read_response_body_chunk()
			if chunk.size() == 0:
				await get_tree().process_frame
				continue
			var new_line = chunk.get_string_from_ascii()
			print("GOT: ", new_line)
		# Done!
