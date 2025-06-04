extends Node

@export var config : Player2Config
@export var system_message : String = "You are a helpful agent that helps out the player!"
@export var tool_calls : Array[AIToolCall]
@export var tool_call_choice : String = "Use whatever tools necessary to help the player when they need it."

signal tool_called(tool_name : String)
signal chat_received(message : String)
signal chat_failed(error_code : int)

func print_client_version() -> void:
	Player2.get_health(config,
		func(result : Player2Schema.Health):
			print(result.client_version)
	)

func chat(message : String) -> void:
	# Build the system + user message
	# TODO: History, queue, etc.
	var request := Player2Schema.ChatCompletionRequest.new()

	# System message
	var system_msg := Player2Schema.Message.new()
	system_msg.role = "system"
	system_msg.content = system_message

	# User message
	var user_msg := Player2Schema.Message.new()
	user_msg.role = "user"
	user_msg.content = message

	request.messages = []
	request.messages.assign([system_msg, user_msg])

	# Tools
	request.tools = []
	request.tools.assign(tool_calls.map(func(simple_tool_call : AIToolCall):
		var tool_call := Player2Schema.Tool.new()
		tool_call.type = "function"
		var f := Player2Schema.Function.new()
		f.name = simple_tool_call.name
		f.description = simple_tool_call.description
		var p := Player2Schema.Parameters.new()
		p.type = "object"
		p.properties = Dictionary()
		p.required = []

		f.parameters = p
		tool_call.function = f

		return tool_call
	))
	request.tool_choice = tool_call_choice

	Player2.chat(config, request, func(result : Player2Schema.ChatCompletionResponse):
		for choice in result.choices:
			var reply = choice.message.content
			chat_received.emit(reply)
			for tool_call in choice.message.tool_calls:
				var tool_name = tool_call.function.name
				tool_called.emit(tool_name)
	,
	func(error_code : int) :
		chat_failed.emit(error_code)
)

var timeout = 10
func _process(delta: float) -> void:
	timeout = timeout - 1
	if timeout == 0:
		chat("Hello! Can you jump for me?")
