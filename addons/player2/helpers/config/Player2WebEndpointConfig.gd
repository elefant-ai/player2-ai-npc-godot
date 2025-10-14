@tool
class_name Player2WebEndpointConfig
extends Player2EndpointConfig

@export var root : String = "https://api.player2.game"
@export var root_internal_site : String = "{origin}/_api"
@export var internal_site_origin : String = "player2.game"

@export var chat : String = "{root}/v1/chat/completions"
@export var health : String = "{root}/v1/health"
@export var joules : String = "{root}/v1/joules"

@export var tts_speak: String = "{root}/v1/tts/speak"
@export var tts_speak_stream: String = "{root}/v1/tts/stream"
@export var tts_voices : String = "{root}/v1/tts/voices"

@export var get_selected_characters : String = "{root}/v1/selected_characters"

@export var image_generate : String = "{root}/v1/image/generate"

@export var auth_start : String = "{root}/v1/login/device/new"
@export var auth_poll : String = "{root}/v1/login/device/token"

@export var stt_stream : String = "{root}/v1/stt/stream"
@export var stt_protocol : String = "wss"

@export var endpoint_check = "{root}/v1/health"

# Can override if we detect we're a web build on site
var _using_site : bool = false
var _using_site_origin : String

func set_using_site(origin : String):
	_using_site_origin = origin
	_using_site = true

func path(path_property : String) -> String:
	if _using_site:
		var origin = _using_site_origin

		var root : String = root_internal_site

		if root and origin:
			root = root.replace("{origin}", origin)

		var result : String = get(path_property)
		if root and result:
			result = result.replace("{root}", root)

		return result
	return super.path(path_property)
