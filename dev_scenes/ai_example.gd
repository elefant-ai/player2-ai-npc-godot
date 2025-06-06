extends Node

# TODO: Tools: Scan functions (self) for child implementations...
# - BAD IDEA?
# - PUBLIC/PRIVATE ISSUES

# TODO: Move this to its own dedicated player2 implementation node
# with its own player2 Agent icon etc.

@export var config : Player2Config
@export_multiline var system_message : String = "You are a helpful agent that helps out the player!"
# TODO: Validate conversation_history_size > 0 and conversation_history_size > conversation_summary_buffer
@export_subgroup("Conversation and Summary")
@export var conversation_history_size : int = 64
@export var conversation_summary_buffer : int = 48
@export_multiline var summary_message : String = \
"The agent has been chatting with the player.
Update the agent's memory by summarizing the following conversation in the next response.
Use natural language, not JSON. Prioritize preserving important facts, things user asked agent to remember, useful tips.

Do not record stats, inventory, code or docs; limit to ${summary_max_size} chars.
"
@export var summary_max_size : int = 500
@export_multiline var summary_prefix : String = "Summary of earlier events: ${summary}"

@export_subgroup("Tool Calls", "tool_calls")
@export var tool_calls : Array[AIToolCall]
@export var tool_calls_choice : String = "Use whatever tools necessary to help the player when they need it."

signal tool_called(tool_name : String)
signal chat_received(message : String)
signal chat_failed(error_code : int)

var _messsage_queued : bool = false

class ConversationMessage:
	@export var message : String
	@export var role : String
var _conversation_history : Array[ConversationMessage]

var _summarizing_history : bool = false
var _current_summary : String = ""

# Gets client version, useful endpoint test
func print_client_version() -> void:
	Player2.get_health(config,
		func(result):
			print(result.client_version)
	)

# Add chat message to our history
func chat(message : String) -> void:
	#print("CHAT")
	#print(message)

	var conversation_message : ConversationMessage = ConversationMessage.new()
	conversation_message.message = message
	conversation_message.role = "user"
	_conversation_history.push_back(conversation_message)

	_messsage_queued = true

	if _summarizing_history:
		# do not process conversation history, just push it
		return

	_process_conversation_history()

func _process_conversation_history() -> void:

	# Wait while we summarize please...
	if _summarizing_history:
		return

	# max size
	if _conversation_history.size() > conversation_history_size:
		print("Conversation history limit reached: Cropping and summarizing")
		# crop conversation history
		var to_summarize := _conversation_history.slice(0, conversation_summary_buffer)
		_conversation_history = _conversation_history.slice(_conversation_history.size() - conversation_history_size)

		# summarize a fragment of the space we cropped out and push that to the start...
		if to_summarize.size() > 0:
			_summarizing_history = true
			_summarize_history_internal(
				to_summarize,
				_current_summary,
				func(result : String):
					# We got our summary from the endpoint, set and move on.
					_current_summary = result
					if _current_summary.length() > summary_max_size:
						_current_summary = _current_summary.substr(0, summary_max_size)
					_summarizing_history = false,
				func():
					# error! Do nothing for now.
					_summarizing_history = false
			)
			

# Send a call to get a summary of a list of messages, completing with a single message that summarizes the conversation.
func _summarize_history_internal(messages : Array[ConversationMessage], previous_summary : String, on_completed : Callable, on_fail : Callable) -> void:
	var request := Player2Schema.ChatCompletionRequest.new()

	# System message
	var system_msg := Player2Schema.Message.new()
	system_msg.role = "system"
	system_msg.content = summary_message.replace("${summary_max_size}", str(summary_max_size))

	# Get all previous messages as a log...
	var messages_log = ""
	if previous_summary.length() != 0:
		messages_log += "(previous summary: \"" + previous_summary + "\")"
	for message : ConversationMessage in messages:
		messages_log += message.role + ": " + message.message + "\n"
	var user_msg = Player2Schema.Message.new()
	user_msg.role = "user"
	user_msg.content = messages_log

	var req_messages = [system_msg, user_msg]

	# Simply add to list
	# The agent interprets this as history, and can reply with something like "ok cool"
	# so don't do it this way.
	#for message : ConversationMessage in messages:
		#var user_msg = Player2Schema.Message.new()
		#user_msg.role = message.role
		#user_msg.content = message.message
		#req_messages.push_back(user_msg)

	request.messages.assign(req_messages)
	Player2.chat(config, request,
		func(result):
			if result.choices.size() != 0:
				var reply = result.choices.get(0).message.content
				on_completed.call(reply)
				# done, good.
				return
			printerr("Invalid reply: ", JsonClassConverter.class_to_json_string(result) )
			on_fail.call(),
		on_fail
	)

func _append_agent_reply_to_history(message : String):
	var msg := ConversationMessage.new()
	msg.role = "assistant"
	msg.message = message
	_conversation_history.push_back(msg)

func _generate_tools() -> Array[Player2Schema.Tool]:
	var result : Array[Player2Schema.Tool] = []
	result.assign(tool_calls.map(
		func(simple_tool_call : AIToolCall):
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
	return result

func _process_chat_api() -> void:
	if _summarizing_history:
		return

	_process_conversation_history()

	# Additional check in case if we happened to start summarizing (just wait for it to finish)
	if _summarizing_history:
		return

	if not _messsage_queued:
		return

	_messsage_queued = false

	# Build the API request

	var request := Player2Schema.ChatCompletionRequest.new()

	# System message
	var system_msg := Player2Schema.Message.new()
	system_msg.role = "system"
	system_msg.content = system_message

	var req_messages = [system_msg]
	
	# Summary message
	if not _current_summary.is_empty():
		var summary_msg := Player2Schema.Message.new()
		summary_msg.role = "assistant"
		summary_msg.content = summary_prefix.replace("${summary}", _current_summary)
		req_messages.push_back(summary_msg)

	# History
	for conversation_element in _conversation_history:
		var msg := Player2Schema.Message.new()
		msg.role = conversation_element.role
		msg.content = conversation_element.message
		req_messages.push_back(msg)

	request.messages = []
	request.messages.assign(req_messages)

	# Tools
	request.tools = []
	request.tools = _generate_tools()
	request.tool_choice = tool_calls_choice

	Player2.chat(config, request,
		func(result):
			for choice in result.choices:
				var reply : String = choice.message.content
				_append_agent_reply_to_history(reply)
				chat_received.emit(reply.trim_suffix("\n"))
				# Process tool calls IF they are present
				if 'tool_calls' in choice.message:
					for tool_call in choice.message.tool_calls:
						var tool_name = tool_call.function.name
						tool_called.emit(tool_name),
		func(error_code : int) :
			chat_failed.emit(error_code)
	)

func _process(delta: float) -> void:
	_process_chat_api()
