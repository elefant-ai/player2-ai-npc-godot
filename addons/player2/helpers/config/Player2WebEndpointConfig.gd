class_name Player2WebEndpointConfig
extends Player2EndpointConfig

@export var root : String = "https://api.player2.game"

@export var chat : String = "{root}/v1/chat/completions"
@export var health : String = "{root}/v1/health"
@export var tts_speak: String = "{root}/v1/tts/speak"
@export var get_selected_characters : String = "{root}/v1/selected_characters"

@export var auth_start : String = "{root}/v1/login/device/new"
@export var auth_poll : String = "{root}/v1/login/device/token"

@export var stt_stream : String = "{root}/v1/stt/stream"
@export var stt_protocol : String = "wss"

@export var endpoint_check = "{root}/v1/health"
