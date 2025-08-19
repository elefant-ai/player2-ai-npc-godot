class_name Player2WebEndpointConfig
extends Resource

@export var chat : String = "https://api.player2.game/v1/chat/completions"
@export var health : String = "https://api.player2.game/v1/health"
@export var tts_speak: String = "https://api.player2.game/v1/tts/speak"
@export var get_selected_characters : String = "https://api.player2.game/v1/selected_characters"

@export var auth_start : String = "https://api.player2.game/v1/login/device/new"
@export var auth_poll : String = "https://api.player2.game/v1/login/device/token"

@export var endpoint_check = "https://api.player2.game"
