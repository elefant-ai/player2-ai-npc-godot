class_name Player2Config
extends Resource

@export var player2_game_key = "my_game"

@export_group("Endpoints", "endpoint")
@export var endpoint_chat : String = "http://127.0.0.1:4315/v1/chat/completions"
@export var endpoint_health : String = "http://127.0.0.1:4315/v1/health"
