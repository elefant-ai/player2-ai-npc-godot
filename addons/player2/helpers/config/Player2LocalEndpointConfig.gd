class_name Player2LocalEndpointConfig
extends Resource

@export var chat : String = "http://127.0.0.1:4315/v1/chat/completions"
@export var health : String = "http://127.0.0.1:4315/v1/health"
@export var tts_speak: String = "http://127.0.0.1:4315/v1/tts/speak"
@export var tts_stop: String = "http://127.0.0.1:4315/v1/tts/stop"
@export var get_selected_characters : String = "http://127.0.0.1:4315/v1/selected_characters"
@export var stt_start : String = "http://127.0.0.1:4315/v1/stt/start"
@export var stt_stop : String = "http://127.0.0.1:4315/v1/stt/stop"

@export var endpoint_check = "http://127.0.0.1:4315/v1/health"
