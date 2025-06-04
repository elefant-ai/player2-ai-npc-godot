class_name Player2Schema

class ChatCompletionRequest extends Resource:
	@export var messages : Array[Message]
	@export var tools : Array[Tool]
	@export var tool_choice : String

class ChatCompletionResponse extends Resource:
	@export var choices : Array[ResponseMessage]

class Message extends Resource:
	@export var role : String
	@export var content : String
	@export var tool_call_id : String
	@export var tool_calls : Array[ToolCall]

class ToolCall extends Resource:
	@export var id : String
	@export var type : String
	@export var function : FunctionCall

class FunctionCall extends Resource:
	@export var name : String
	@export var arguments : String

class Tool extends Resource:
	@export var type : String # only "function" is supported
	@export var function: Function

class Function extends Resource:
	@export var name : String
	@export var description : String
	@export var parameters : Parameters

class Parameters extends Resource:
	@export var type : String
	@export var properties : Dictionary
	@export var required : Array[String]

class Property extends Resource:
	@export var type : String
	@export var description : String

class ResponseMessage extends Resource:
	@export var message : Content

class Content extends Resource:
	@export var content : String
	@export var tool_calls : Array[ToolCall]

class Health extends Resource:
	@export var client_version : String
