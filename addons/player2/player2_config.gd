class_name Player2Config
extends Resource

@export var player2_game_key = "my_game"

@export_group("Error handling", "error")
@export var error_log_ui : bool = true

@export_group("Endpoints", "endpoint")
@export var endpoint_chat : String = "http://127.0.0.1:4315/v1/chat/completions"
@export var endpoint_health : String = "http://127.0.0.1:4315/v1/health"
@export var endpoint_tts_speak: String = "http://127.0.0.1:4315/v1/tts/speak"
@export var endpoint_tts_stop: String = "http://127.0.0.1:4315/v1/tts/stop"
@export var endpoint_get_selected_characters : String = "http://127.0.0.1:4315/v1/selected_characters"
@export var endpoint_stt_start : String = "http://127.0.0.1:4315/v1/stt/start"
@export var endpoint_stt_stop : String = "http://127.0.0.1:4315/v1/stt/stop"

@export_group("Request Delay")
@export var request_too_much_delay_seconds : float = 3
