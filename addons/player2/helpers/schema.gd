class_name Player2Schema

# DO NOT deserialize into these
# ONLY use these for SENDING REQUESTS (not responses)
# Because proper clean deserialization of nested classes isn't quite there yet
# (maybe can be done but yeah)

class ChatCompletionRequest extends Resource:
	@export var messages : Array[Player2Schema.Message]
	# TODO: Add these back in conditionally
	#@export var tools : Array[Player2Schema.Tool]
	#@export var tool_choice : String

class ChatCompletionResponse extends Resource:
	@export var choices : Array[Player2Schema.ResponseMessage]

class Message extends Resource:
	@export var role : String
	@export var content : String
	# TODO: Add these back in conditionally
	#@export var tool_call_id : String
	#@export var tool_calls : Array[Player2Schema.ToolCall]

class ToolCall extends Resource:
	@export var id : String
	@export var type : String
	@export var function : Player2Schema.FunctionCall

class FunctionCall extends Resource:
	@export var name : String
	@export var arguments : String

class Tool extends Resource:
	@export var type : String # only "function" is supported
	@export var function: Player2Schema.Function

class Function extends Resource:
	@export var name : String
	@export var description : String
	@export var parameters : Player2Schema.Parameters

class Parameters extends Resource:
	@export var type : String
	@export var properties : Dictionary
	@export var required : Array[String]

class Property extends Resource:
	@export var type : String
	@export var description : String

class ResponseMessage extends Resource:
	@export var message : Player2Schema.Content

class Content extends Resource:
	@export var content : String
	@export var tool_calls : Array[Player2Schema.ToolCall]

class Health extends Resource:
	@export var client_version : String

class TTSRequest extends Resource:
	@export var text : String
	@export var play_in_app : bool
	@export var speed : float
	@export var voice_gender : String
	@export var voice_language : String
	@export var voice_ids : Array[String]
	#@export var audio_format : String

class STTStartRequest extends Resource:
	@export var timeout : float
