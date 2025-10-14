@tool
class_name Player2LocalEndpointConfig
extends Player2EndpointConfig

@export var root : String = "http://127.0.0.1:4315"

@export var chat : String = "{root}/v1/chat/completions"
@export var health : String = "{root}/v1/health"
@export var joules : String = "{root}/v1/joules"

@export var tts_speak: String = "{root}/v1/tts/speak"
@export var tts_stop: String = "{root}/v1/tts/stop"
@export var tts_voices: String = "{root}/v1/tts/voices"

@export var get_selected_characters : String = "{root}/v1/selected_characters"
@export var image_generate : String = "{root}/v1/image/generate"
@export var stt_start : String = "{root}/v1/stt/start"
@export var stt_stop : String = "{root}/v1/stt/stop"
@export var webapi_login : String = "{root}/v1/login/web/{client_id}"

@export var endpoint_check = "{root}/v1/health"
