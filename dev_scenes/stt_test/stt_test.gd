extends Node

@onready var response : Label = $Response
@onready var stt : Player2STT = $Player2STT

func _ready() -> void:
	print("Simple Chat START")

	stt.stt_partial_received.connect(func(partial_message_result : String):
		print("(partial :", partial_message_result, ")")
		response.text = partial_message_result
	)
	stt.stt_received.connect(func(message : String):
		print("RECEIVED:", message)
		response.text = message
	)
	stt.stt_failed.connect(func(message, code):
		print("FAILED:", message, "code =",code)
		response.text = "ERROR: " + message
	)
	Player2API.establish_connection(func():
		print("yay stt_test connection established")
		stt.start_stt()
	)
