@tool
## AI NPC using the Player2 API.
class_name Player2AINPC
extends Node

@export_tool_button("Clear Conversation History")
var editor_tool_button_clear_conversation_history = _clear_conversation_history_tool

## The name of this NPC character
@export var character_name : String = "Robot"
## Describe who the NPC character is
@export_multiline var character_description = "A helpful agent who is there to help out the player and be chatty with them!"

#@export_group ("Player2 Selected Character", "use_player2_selected_character")
## Selected character from the player's Player2 account.
## If true, the agent will play the character of the player's selected Player2 Agent.
@export var use_player2_selected_character : bool = false:
	set(val):
		use_player2_selected_character = val
		# for the agent to make updates
		notify_property_list_changed()
## If there are multiple agents (CURRENTLY UNSUPPORTED), pick this index. Set to -1 to automatically pick a unique agent
@export_range(-1, 99999) var use_player2_selected_character_desired_index : int = -1

## More specific description on how to behave.
@export_multiline var character_system_message = "Match the player's mood. Be direct with your replies, but if the player is talkative then be talkative as well."

## If true, will save our conversation history to godot's user:// directory and will auto load on startup from the history file.
@export var auto_store_conversation_history : bool = true:
	set(val):
		auto_store_conversation_history = val
		notify_property_list_changed()
## If true, will greet the player when entering.
@export var greet_on_entry : bool = true

@export_group("Tool Calls", "tool_calls")
## Set this to an object to scan for functions in that object to call
@export var tool_calls_scan_node_for_functions : Array[Node]:
	set(new_nodes):
		tool_calls_scan_node_for_functions = new_nodes
		_validate_tool_call_definitions()
		# notify_property_list_changed()
@export_tool_button("Rescan functions") var tool_calls_rescan_functions = _validate_tool_call_definitions
@export var tool_calls_function_definitions : ToolcallFunctionDefinitions

## More lower level Character configuration.
@export var character_config : Player2AICharacterConfig = Player2AICharacterConfig.new():
	set(new_config):
		character_config = new_config
		character_config.property_list_changed.connect(notify_property_list_changed)
		notify_property_list_changed()

## More lower level Chat configuration.
@export var chat_config : Player2AIChatConfig = load("res://addons/player2/chat_config.tres")

var _tts_configured = false
## Override TTS component to use (if you want a 3D audio source for example)
@export var tts : Player2TTS:
	get:
		if Engine.is_editor_hint():
			return tts
		if !tts:
			tts = Player2TTS.new()
			tts.config = character_config.tts
			add_child(tts)

		if !_tts_configured and tts:
			# hooks
			tts.tts_began.connect(func(): tts_began.emit())
			tts.tts_ended.connect(func(): tts_ended.emit())
			_tts_configured = true
		return tts

## Whether the agent is thinking (coming up with a reply to a chat, stimulus, or summarizing the chat)
var thinking: bool:
	set(value):
		if thinking != value:
			thinking = value
			if thinking:
				thinking_began.emit()
			else:
				thinking_ended.emit()

## Called when our ai agent starts thinking
signal thinking_began
## Called when our ai agent stops thinking and replies
signal thinking_ended
## Called when our ai agent calls a tool (used for manual tool calling)
signal tool_called(function_name : String, args : Dictionary)
## Called when our ai agent talks
signal chat_received(message : String)
## Called when our ai agent fails a chat
signal chat_failed(body : String, error_code : int)
## Called when TTS is called
signal tts_began
## Called when TTS ends (ONLY if `use_local_audio` is set to true in character configuration)
signal tts_ended

var _messsage_queued : bool = false

# TODO: Move this class and serialization to a helper
class ConversationMessage:
	@export var message : String
	@export var role : String
	@export var tool_calls_optional : Array[Dictionary]
	static func serialize_list(conversation_history  : Array[ConversationMessage], tool_calls_api : bool = true) -> String:
		return JSON.stringify(conversation_history.map(func(m : ConversationMessage):
			var result = {"message": m.message, "role": m.role}
			if tool_calls_api:
				result["tool_calls_optional"] = m.tool_calls_optional
			return result
			))
	static func deserialize_list(conversation_history_json : String, tool_calls_api : bool = true) -> Array[ConversationMessage]:
		var result : Array[ConversationMessage] = []
		var json : Array = JSON.parse_string(conversation_history_json)
		result.assign(json.map(func(d : Dictionary): 
			var m := ConversationMessage.new()
			m.role = d["role"]
			m.message = d["message"]
			if tool_calls_api and "tool_calls_optional" in d:
				m.tool_calls_optional = []
				m.tool_calls_optional.assign(d["tool_calls_optional"])
			return m
		))
		return result

var conversation_history : Array[ConversationMessage]

var _summarizing_history : bool = false
var _current_summary : String = ""

## Mapping of tool call name -> Callable
var _tool_call_func_map : Dictionary

## Current selected agent info
var _selected_character : Dictionary
var _selected_character_index := -1

var _queue_process_timer : Timer

const TOOL_CALL_MESSAGE_OPTIONAL_ARG_NAME = "MESSAGE_ARG"

## prints the client version, useful endpoint test
func print_client_version() -> void:
	Player2API.get_health(
		func(result):
			print(result.client_version)
	)

func _queue_message(message : ConversationMessage, silent : bool = false) -> void:
	conversation_history.push_back(message)
	if not silent:
		_messsage_queued = true
	if _summarizing_history:
		# do not process conversation history, just push it
		return
	_processconversation_history()

func _construct_user_message_json(speaker_name: String, speaker_message : String, stimuli : String, world_status : String) -> String:
	var result : Dictionary ={}
	result["speaker_name"] = speaker_name
	result["speaker_message"] = speaker_message
	result["stimuli"] = stimuli
	result["world_status"] = world_status
	return JSON.stringify(result)

func _get_default_conversation_history_filepath() -> String:
	var char_name = _selected_character["name"] if _selected_character else character_name
	var char_desc = _selected_character["description"] if _selected_character else "" # leave blank since user might update it more rapidly
	var desc_hash = hash(char_desc)
	var result = "user://HISTORY_" + char_name + "_" + str(desc_hash) + ".json"
	return result

## Save the current conversation history to a file. Leave blank to use our default location.
## Alternatively, read and serialize `conversation_history` manually.
func save_conversation_history(filename : String = "") -> void:
	if filename.is_empty():
		filename = _get_default_conversation_history_filepath()

	var serialized = ConversationMessage.serialize_list(conversation_history)
	print("Saving conversation history to " + filename)
	print(serialized)

	var file = FileAccess.open(filename, FileAccess.WRITE)
	file.store_string(serialized)
	file.close()

func _clear_conversation_history_tool():
	clear_conversation_history()
func clear_conversation_history(filename : String = ""):
	if filename.is_empty():
		filename = _get_default_conversation_history_filepath()
	if !FileAccess.file_exists(filename):
		print("(no conversation history found at " + filename + ")")
	else:
		var e := DirAccess.remove_absolute(filename)
		if e != OK:
			print("(failed to delete conversation history at " + filename + ". It might not be present.)")
		else:
			print("Successfully deleted conversation history from " + filename)
	notify_property_list_changed()

func _on_entry_load_conversation_or_greet():
	if not (auto_store_conversation_history and load_conversation_history()):
		if greet_on_entry and !chat_config.first_entry_message.is_empty():
			notify(chat_config.first_entry_message)

## Load our conversation history from a file. Leave blank to use our default location.
## Alternatively, set `conversation_history` manually, and for a "welcome back" message use `notify`.
func load_conversation_history(notify_agent_for_welcome_message: bool = true, message : String = "", filename : String = "") -> bool:
	if filename.is_empty():
		filename = _get_default_conversation_history_filepath()
	print("Loading conversation history from " + filename)

	if not FileAccess.file_exists(filename):
		print("(no conversation history found at " + filename + ")")
		return false

	var file = FileAccess.open(filename, FileAccess.READ)

	var content := file.get_as_text()
	file.close()

	#print("content" + content)

	var deserialized : Array[ConversationMessage] = ConversationMessage.deserialize_list(content)
	
	conversation_history = deserialized

	# Notify welcome message
	if greet_on_entry and notify_agent_for_welcome_message:
		if message.is_empty():
			message = chat_config.auto_load_entry_message
		notify(message)
	return true

## Add chat message to our history.
## This is a user talking to the agent.
func chat(message : String, speaker : String = "User") -> void:
	var conversation_message : ConversationMessage = ConversationMessage.new()
	conversation_message.message = _construct_user_message_json(speaker, message, "", get_agent_status())
	conversation_message.role = "user"
	_queue_message(conversation_message)

## Add a notification message to our history
## This is the developer talking to the agent, letting it know that something happened.
## You can pass a "silent" flag to not have the agent respond and simply append to the conversation history.
func notify(message : String, silent : bool = false) -> void:
	var conversation_message : ConversationMessage = ConversationMessage.new()
	conversation_message.message = _construct_user_message_json("", "", message, get_agent_status())
	conversation_message.role = "user"
	_queue_message(conversation_message, silent)

## Stops TTS
func stop_tts() -> void:
	tts.stop()

## Check if our history has too many messages and prompt for a summary/cull
func _processconversation_history() -> void:

	# Wait while we summarize please...
	if _summarizing_history:
		return

	# max size
	if conversation_history.size() > chat_config.conversation_history_size:
		print("Conversation history limit reached: Cropping and summarizing")
		# crop conversation history
		var to_summarize := conversation_history.slice(conversation_history.size() - chat_config.conversation_summary_buffer)
		conversation_history = conversation_history.slice(min (conversation_history.size() - 1, chat_config.conversation_history_size))

		# summarize a fragment of the space we cropped out and push that to the start...
		if to_summarize.size() > 0:
			_summarizing_history = true
			_summarize_history_internal(
				to_summarize,
				_current_summary,
				func(result : String):
					# We got our summary from the endpoint, set and move on.
					_current_summary = result
					if _current_summary.length() > chat_config.summary_max_size:
						_current_summary = _current_summary.substr(0, chat_config.summary_max_size)
					_summarizing_history = false,
				func(msg, code):
					# error! Do nothing for now.
					_summarizing_history = false
			)

## Send an API call to get a summary of a list of messages, completing with a single message that summarizes the conversation.
func _summarize_history_internal(messages : Array[ConversationMessage], previous_summary : String, on_completed : Callable, on_fail : Callable) -> void:
	var request := Player2Schema.ChatCompletionRequest.new()

	# System message
	var system_msg := Player2Schema.Message.new()
	system_msg.role = "system"
	system_msg.content = chat_config.summary_message.replace("${summary_max_size}", str(chat_config.summary_max_size))

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
	thinking = true
	Player2API.chat(request,
		func(result):
			thinking = false
			if result.choices.size() != 0:
				var reply = result.choices.get(0).message.content
				on_completed.call(reply)
				# done, good.
				return
			var msg = "Invalid reply: " + JsonClassConverter.class_to_json_string(result) 
			printerr(msg)
			on_fail.call(msg, -1234),
		func(body, code):
			thinking = false
			if on_fail:
				on_fail.call(body, code)
	)

## Append a reply message to our history, assuming it's from the assistant.
#func _append_agent_reply_to_history(message : String, tool_calls_json : Array[Dictionary] = []):
	#if !message or message.is_empty():
		#return
	#var msg := ConversationMessage.new()
	#msg.role = "assistant"
	#msg.message = message
	#msg.tool_calls_optional = tool_calls_json
	#conversation_history.push_back(msg)
#func _append_agent_action_to_history(message : String):
	#var msg := ConversationMessage.new()
	#msg.role = "developer"
	#msg.message = message
	#conversation_history.push_back(msg)
#func _append_agent_tool_call_to_history(tool_calls_json: Array[Dictionary]):
	#var msg := ConversationMessage.new()
	#msg.role = "developer"
	#msg.message = "Tool Call Performed"
	#msg.tool_calls_optional = tool_calls_json
	#conversation_history.push_back(msg)

# TODO: Move to helper file
static func _get_tool_call_param_from_method_arg_dictionary(method_arg : Dictionary) -> AIToolCallParameter:
	var result := AIToolCallParameter.new()
	result.name = method_arg["name"]

	match method_arg["type"]:
		TYPE_INT:
			result.type = AIToolCallParameter.Type.INTEGER
		TYPE_FLOAT:
			result.type = AIToolCallParameter.Type.NUMBER
		TYPE_BOOL:
			result.type = AIToolCallParameter.Type.BOOLEAN
		TYPE_STRING:
			result.type = AIToolCallParameter.Type.STRING
		_:
			# Unsupported type
			printerr("Unsupported JSON type for the following method argument: " + JSON.stringify(method_arg))
			return null
	return result

func _scan_node_tool_call_functions(node : Node) -> Array[Dictionary]:
	var result : Array[Dictionary] = []

	if !node:
		return result

	var self_funcs_to_ignore : Array[String] = []
	# Get our class functions so we don't worry about it
	var t := Player2AINPC.new()
	self_funcs_to_ignore.assign(t.get_method_list().map(func (t): return t["name"]))
	t.queue_free()

	# Ignore node root functions
	var node_funcs_to_ignore : Array[String] = []
	var n := Node.new()
	node_funcs_to_ignore.assign(n.get_method_list().map(func (t): return t["name"]))
	n.queue_free()
	
	var functions := node.get_method_list()
	var is_self := node == self
	for function in functions:
		var f_name : String = function["name"]

		# our functions or base object functions
		if is_self:
			if self_funcs_to_ignore.has(f_name):
				continue
		else:
			if node_funcs_to_ignore.has(f_name):
				continue

		# private functions
		if f_name.begins_with("_"):
			continue

		# Some internal stuff
		if f_name.begins_with("@"):
			continue

		result.append(function)

	return result

# TODO: Cache this
## Scans functions in a provided class to consider as being tool calls
func _scan_funcs_for_tools() -> Array[AIToolCall]:
	var result : Array[AIToolCall] = []

	var nodes_to_scan : Array[Node] = []
	if tool_calls_scan_node_for_functions:
		nodes_to_scan.append_array(tool_calls_scan_node_for_functions)

	for node in nodes_to_scan:
		
		var is_self := node == self
		var functions := _scan_node_tool_call_functions(node)

		var valid_function_names = [] if (!tool_calls_function_definitions or !tool_calls_function_definitions.definitions) else tool_calls_function_definitions.definitions.filter(func(d): return d and d.enabled).map(func(d): return d.name)

		#print("VALID FUNCTION NAMES")
		#print(valid_function_names)

		for function in functions:
			var f_name = function["name"]

			# tool call filter based on chat_config (by default OMIT)
			if !tool_calls_function_definitions or !tool_calls_function_definitions.definitions:
				continue
			var function_definition_index = tool_calls_function_definitions.definitions.find_custom(func(d): return d.name == f_name)
			if function_definition_index == -1:
				continue
			var function_definition := tool_calls_function_definitions.definitions[function_definition_index]

			# Configured as NOT enabled
			if !function_definition.enabled:
				continue

			var tool_call := AIToolCall.new()

			# name and description
			tool_call.function_name = f_name
			tool_call.description = function_definition.description_comment

			# args
			tool_call.args = []
			for arg : Dictionary in function["args"]:
				var tc_arg := _get_tool_call_param_from_method_arg_dictionary(arg)
				if tc_arg:
					tool_call.args.append(tc_arg)

			# do not allow empty description
			if !tool_call.description or tool_call.description.is_empty():
				tool_call.description = "(empty)"

			result.append(tool_call)

			# Update callable function as well
			_tool_call_func_map[f_name] = Callable(node, f_name)

	return result

## Converts our representation of a tool call to the schema representation
func _convert_tool_call(simple_tool_call : AIToolCall) -> Player2Schema.Tool:
	var function_name = simple_tool_call.function_name
	var tool_call := Player2Schema.Tool.new()
	tool_call.type = "function"
	var f := Player2Schema.Function.new()
	f.name = function_name
	f.description = simple_tool_call.description

	var p := Player2Schema.Parameters.new()
	p.type = "object"
	p.properties = Dictionary()
	p.required = []

	# Arguments
	for arg in simple_tool_call.args:
		var arg_name := arg.name
		var arg_t := Dictionary()
		arg_t["type"] = AIToolCallParameter.arg_type_to_schema_type(arg.type)
		arg_t["description"] = arg.description
		if arg.type == AIToolCallParameter.Type.ENUM:
			var enum_types_t : Array[String] = arg.enum_list
			arg_t["enum"] = enum_types_t
		p.properties[arg_name] = arg_t
		p.required.push_back(arg_name)
		pass

	# Add our optional message arg
	# Done because "content" field is empty otherwise
	var optional_message_arg_t := Dictionary()
	optional_message_arg_t["type"] = AIToolCallParameter.arg_type_to_schema_type(AIToolCallParameter.Type.STRING)
	optional_message_arg_t["description"] = chat_config.tool_calls_message_optional_arg_description
	p.properties[TOOL_CALL_MESSAGE_OPTIONAL_ARG_NAME] = optional_message_arg_t
	p.required.push_back(TOOL_CALL_MESSAGE_OPTIONAL_ARG_NAME)

	f.parameters = p
	tool_call.function = f

	return tool_call

## Generate our tool calls
func _generate_manual_tools() -> Array[AIToolCall]:
	var our_tools : Array[AIToolCall] = []
	our_tools.append_array(get_manual_tool_calls(_tool_call_func_map))
	our_tools.append_array(_scan_funcs_for_tools())
	return our_tools

## Generate our schema tool calls
func _generate_schema_tools() -> Array[Player2Schema.Tool]:

	var our_tools : Array[AIToolCall] = _generate_manual_tools()

	var result : Array[Player2Schema.Tool] = []
	result.assign(our_tools.map(_convert_tool_call))

	return result

func _run_chat_internal(message_dictionary : Dictionary) -> void:
	var message : String = message_dictionary["reply"]
	var voice_instructions : String = message_dictionary["voice_instructions"]
	if message and !message.strip_edges().is_empty():
		var reply_message := message.trim_suffix("\n") 
		chat_received.emit(reply_message)
		if character_config.tts_enabled:
			var voice_ids : Array[String] = []
			if _selected_character:
				voice_ids.assign(_selected_character["voice_ids"])
			tts.speak(reply_message, voice_ids, voice_instructions)

func _tool_call_json_to_tool_call_reply(tool_call_json : Array) -> Array[AIToolCallReply]:
	var result : Array[AIToolCallReply] = []
	for tool_call : Dictionary in tool_call_json:
		var tool_call_reply := AIToolCallReply.new()
		var tool_name : String = tool_call.function.name

		tool_call_reply.function_name = tool_name

		#tool_name = "announce"
		var args : Dictionary = JSON.parse_string(tool_call.function.arguments)
		print("Got args: ")
		print(args)
		if args.has(TOOL_CALL_MESSAGE_OPTIONAL_ARG_NAME):
			var tool_call_reply_message : String = args[TOOL_CALL_MESSAGE_OPTIONAL_ARG_NAME]
			args.erase(TOOL_CALL_MESSAGE_OPTIONAL_ARG_NAME)
			# For some reason content and message reply gets mixed sometimes? seems like the tool call reply goes first.
			tool_call_reply.optional_message = tool_call_reply_message
		tool_call_reply.args = args

		result.append(tool_call_reply)
	return result

func _tool_call_non_json_content_to_tool_call_reply(reply : Dictionary) -> Array[AIToolCallReply]:
	if !reply.has("function") or !reply["function"]:
		return []
	var f_name : String = reply["function"]
	if !f_name or f_name.is_empty():
		return []
	var result : AIToolCallReply = AIToolCallReply.new()
	result.function_name = f_name
	var f_args : Dictionary = reply["args"] if reply.has("args") else {}
	result.args = f_args

	return [result]

func _parse_llm_message_json(llm_raw_json : String) -> Dictionary:
	llm_raw_json = llm_raw_json.trim_prefix("```json").trim_suffix("```").strip_edges()
	var result = JSON.parse_string(llm_raw_json)
	return result if result else {}


## At an interval, process chats and send to the API if we have something queued.
func _process_chat_api() -> void:
	if _summarizing_history:
		return

	# Don't process new messages while we're thinking, wait to stop thinking...
	if thinking:
		return

	_processconversation_history()

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
	var system_msg_content = chat_config.system_message_organization\
		.replace("${system_message_character}", chat_config.system_message_character)\
		.replace("${system_message_custom}", character_system_message)\
		.replace("${system_message_behavior}", chat_config.system_message_behavior)\
		.replace("${system_message_prompting}", chat_config.system_message_prompting)\
		.replace("${character_name}", _selected_character["name"] if _selected_character else character_name)\
		.replace("${character_description}", _selected_character["description"] if _selected_character else character_description)
	system_msg_content += """
		User message format:
		User messages will have extra information, and will be a JSON of the form:
		{
			"speaker_name" : The name of who is speaking to you. If blank, nobody is talking.,
			"speaker_message": The message that was sent to you. If blank, nothing is said.,
			"stimuli": A new stimuli YOU have received. Could be an observation about the world, a physical sensation, or thought that had just appeared.,
			"world_status": The status of the current game world.,
		}
	"""

	# Process tool calls as part of the prompt if we have them
	for t in _generate_manual_tools():
		var tool_name := t.function_name
		if system_msg_content.contains("{" + tool_name + "}"):
			if _tool_call_func_map.has(tool_name):
				var f : Callable = _tool_call_func_map.get(tool_name)
				# Assume an object is present...
				var o : Object = f.get_object()
				if !o:
					printerr("Failed to call tool call for function " + tool_name + " despite having a callable discovered earlier. Probably a bug!")
					continue
				var result = _convert_tool_call_result(f.call())
				system_msg_content = system_msg_content.replace("{" + tool_name + "}", result)
				print("    sys msg tool call: ", tool_name, "=", result)
			else:
				printerr("Did not find tool call mapped for {" + tool_name + "}. Internal error. Check your system message or manually modify it in code.")

	# TODO: Structured output
	var use_advanced_tts : bool = true

	system_msg_content += """Response format:"""
	if use_advanced_tts:
		system_msg_content += """
			Reply with the following json:
			{
				"reply": string (your reply),
				"voice_instructions": string (extra information for the Text To Speech Voice)
			}
			The "reply" field in the json response will represent what YOU say."""
	system_msg_content += """ Do not prefix with anything (for example, reply with "hello!" instead of "Agent (or my name or anything else): hello!") unless previously instructed."""
	if use_advanced_tts:
		system_msg_content += """
			The "voice_instructions" field is instructions on how to say your reply.
			EXAMPLE REPLY:
			{
				"reply": "Hello! What's up?",
				"voice_instructions": "Speak with a cheerful and energetic tone"
			}
			DO NOT reply with a regular string (ex. "Hello! What's up?"), reply with the ABOVE JSON.
		"""
	else:
		system_msg_content += """
			EXAMPLE REPLY:
			"Hello! How are you doing today?"
		"""

	# prefix & postfix
	system_msg_content = chat_config.system_message_prefix + system_msg_content + chat_config.system_message_postfix

	system_msg.content = system_msg_content

	var req_messages = [system_msg]

	# Summary message
	if not _current_summary.is_empty():
		var summary_msg := Player2Schema.Message.new()
		summary_msg.role = "assistant"
		summary_msg.content = chat_config.summary_prefix.replace("${summary}", _current_summary)
		req_messages.push_back(summary_msg)

	# History
	for conversation_element in conversation_history:
		var msg := Player2Schema.Message.new()
		msg.role = conversation_element.role
		msg.content = conversation_element.message

		# tool calls: add to history if present
		msg.tool_calls = []
		for tool_call_json : Dictionary in conversation_element.tool_calls_optional:
			#print("ASDF pre: " + JSON.stringify(tool_call_json))
			var tc : Player2Schema.ToolCall = Player2Schema.ToolCall.new() # JsonClassConverter.json_to_class(Player2Schema.ToolCall, tool_call_json)
			tc.type = tool_call_json["type"]
			tc.id = tool_call_json["id"]
			tc.function = Player2Schema.FunctionCall.new()
			tc.function.name = tool_call_json["function"]["name"]
			# json encoded as a string here
			tc.function.arguments = tool_call_json["function"]["arguments"]
			#print("ASDF post: " + JsonClassConverter.class_to_json_string(tc))
			#assert(false)
			msg.tool_calls.append(tc)

		req_messages.push_back(msg)

	request.messages = []
	request.messages.assign(req_messages)
	# response_format doesn't seem to work!
	#request.response_format = JSON.parse_string("""
#{
	#"type": "json_schema",
	#"json_schema": {
		#"name": "agent_response",
		#"schema": {
			#"additionalProperties": false,
			#"properties": {
				#"reply": {
					#"type": "string"
				#}
			#},
			#"required": [
				#"reply"
			#],
			#"type": "object"
		#},
		#"strict": true
	#}
#}
	#""")

	# Tools
	request.tools = _generate_schema_tools()
	request.tool_choice = chat_config.tool_calls_choice

	thinking = true
	Player2API.chat(request,
		func(result):
			
			var history_to_append : Array[ConversationMessage] = []
			var functions_to_call : Array[Dictionary] = []

			thinking = false
			for choice in result.choices:
				var message_reply := ""
				if !"message" in choice:
					continue
				var tool_calls_reply : Array[AIToolCallReply]

				# Use openAI spec tool call (less error prone)
				if "content" in choice.message:
					var reply : String = choice.message["content"]
					message_reply = reply.strip_edges()
				if 'tool_calls' in choice.message:
					tool_calls_reply = _tool_call_json_to_tool_call_reply(choice.message["tool_calls"])
				var tool_call_history_messages = []

				if tool_calls_reply:
					for tool_call in tool_calls_reply:
						var tool_name := tool_call.function_name
						#tool_name = "announce"
						var args := tool_call.args
						# Tool call had an optional message to it, just force it to avoid duplicates
						if tool_call.optional_message and not message_reply:
							if !tool_call.optional_message.strip_edges().is_empty():
								message_reply = tool_call.optional_message.strip_edges()
						tool_called.emit(tool_name, args)
						if _tool_call_func_map.has(tool_name):
							# Organize the arguments, call the function...
							var f : Callable = _tool_call_func_map.get(tool_name)
							# Assume an object is present...
							var o : Object = f.get_object()
							if !o:
								printerr("Failed to call tool call for function " + tool_name + " despite having a callable discovered earlier. Probably a bug!")
								continue
							
							var method_index = -1
							var c = 0
							for m in o.get_method_list():
								if m["name"] == tool_name:
									method_index = c
									break
								c += 1

							if method_index == -1:
								printerr("Failed to call tool call for function " + tool_name + " for an available object. Probably a bug! Functions are printed below:")
								print(o.get_method_list())
								continue
							var method : Dictionary = o.get_method_list()[method_index]
							var args_list = method["args"]
							print("arg list names:")
							print(args_list)
							var args_actual : Array = []
							# Compile based on the args list
							for arg_d in args_list:
								var arg_name : String = arg_d["name"]
								var arg_value = args[arg_name]
								args_actual.append(arg_value)

							# Call the function!
							var func_to_call = func():
								return f.callv(args_actual)
							functions_to_call.append({
								"func_to_call": func_to_call,
								"func_name": tool_name
							})

							# History
							tool_call_history_messages.append("Called " + tool_name + " with arguments [" + ",".join(args_actual) + "]")

				# Never have the MESSAGE_ARG thing appear on the message reply. That is invalid!
				var bad_start_possible = "{\"" + TOOL_CALL_MESSAGE_OPTIONAL_ARG_NAME + "\":"
				if message_reply.begins_with(bad_start_possible):
					message_reply = message_reply.substr(bad_start_possible.length())
				# Remove surrounded by quotes...
				if message_reply.begins_with("\"") and message_reply.ends_with("\""):
					message_reply = message_reply.substr(1, message_reply.length() - 2)
				message_reply = message_reply.strip_edges()

				# Try to parse fake JSON
				var parsed := JSON.parse_string(message_reply)
				if not parsed:
					parsed = {}
					parsed["reply"] = message_reply
					parsed["voice_instructions"] = ""

				var agent_message := ConversationMessage.new()
				agent_message.role = "assistant"
				agent_message.message = JSON.stringify(parsed, "\t")
				# Add to the tool calls json if we DO use the tool call API
				if tool_calls_reply:
					agent_message.tool_calls_optional = []
					if 'message' in choice and 'tool_calls' in choice.message:
						agent_message.tool_calls_optional.append_array(choice.message['tool_calls'])
				history_to_append.append(agent_message)

				# Update history
				conversation_history.append_array(history_to_append)

				# Call the functions (they may be async)
				for func_to_call_data in functions_to_call:
					var func_to_call = func_to_call_data["func_to_call"]
					var func_name = func_to_call_data["func_name"]

					Player2AsyncHelper.run_await_async(func_to_call, func(func_result):
						if func_result:
							# convert func result to string
							var func_result_string : String = _convert_tool_call_result(func_result)

							if func_result_string and !func_result_string.is_empty():
								var func_result_notify_string := chat_config.tool_calls_reply_message \
									.replace("${tool_call_name}", func_name) \
									.replace("${tool_call_reply}", func_result_string)
								notify(func_result_notify_string)
						)

				# Agent Reply
				_run_chat_internal(parsed)
				,
		func(body : String, error_code : int):
			thinking = false
			chat_failed.emit(error_code)
	)

func _convert_tool_call_result(func_result : Variant) -> String:
	if func_result is String:
		return func_result
	elif func_result is Dictionary:
		return JSON.stringify(func_result)
	elif func_result is Object:
		return JsonClassConverter.class_to_json_string(func_result)

	return str(func_result)


func _update_selected_character_from_endpoint() -> void:
	thinking = true
	Player2API.get_selected_characters(func(result):
		thinking = false
		var characters : Array = result["characters"] if (result and "characters" in result) else []
		if characters and characters.size() > 0:
			var index = use_player2_selected_character_desired_index
			if index >= characters.size() or index < 0:
				# Invalid index, find a valid one.
				# TODO: get a random index from the least available agents, so we actually fill it up one by one.
				index = randi_range(0, characters.size() - 1)
			_selected_character = characters[index]
			_selected_character_index = index
			# After loaded, then we might also load our conversation history.
			_on_entry_load_conversation_or_greet(),
		func(fail_code):
			thinking = false
			# After loaded, then we might also load our conversation history.
			_on_entry_load_conversation_or_greet(),
	)

## Overwrite to manually define tool calls instead of relying on signals.
## Populate the function map with callables (function name -> callable) to automatically call a tool call function.
func get_manual_tool_calls(function_map : Dictionary) -> Array[AIToolCall]:
	return []

## Overwrite to append agent status to every message
func get_agent_status() -> String:
	return ""

func _get_property_list() -> Array[Dictionary]:
	# TODO: Don't spam (timeout?)
	_validate_tool_call_definitions()
	return []
func _validate_property(property: Dictionary) -> void:
	var name = property.name

	# Don't show character name/description if we're using player2 selected character
	if use_player2_selected_character:
		if name == "character_name" or name == "character_description":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if name == "use_player2_selected_character_desired_index":
			property.usage = PROPERTY_USAGE_NO_EDITOR

	if not auto_store_conversation_history:
		if name == "editor_tool_button_clear_conversation_history":
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# Clear conversation history button: Appear only if we have the conversation history file present
	#if name == "editor_tool_button_clear_conversation_history":
		#var fpath := _get_default_conversation_history_filepath()
		#if !FileAccess.file_exists(fpath):
			#property.usage = PROPERTY_USAGE_NO_EDITOR

func _property_can_revert(property: StringName) -> bool:
	return property == "chat_config" or property == "character_config"

func _property_get_revert(property: StringName) -> Variant:
	if property == "chat_config":
		return load("res://addons/player2/chat_config.tres")
	if property == "character_config":
		return Player2AICharacterConfig.new()
	return null

## Make it so our tool call definitions get auto populated and modified
func _validate_tool_call_definitions() -> void:

	# Editor/tool only
	if !Engine.is_editor_hint():
		return

	if !tool_calls_function_definitions:
		tool_calls_function_definitions = ToolcallFunctionDefinitions.new()
	if !tool_calls_function_definitions.definitions:
		tool_calls_function_definitions.definitions = []

	var valid_functions : Array[Dictionary] = []
	var comment_descriptions : Dictionary = {}

	for node in tool_calls_scan_node_for_functions:
		# Documentation: Parse comments
		if !node:
			continue
		var documentation := Player2FunctionHelper.parse_documentation(node.get_script())
		for f in _scan_node_tool_call_functions(node):
			if documentation.has(f.name):
				if comment_descriptions.has(f.name):
					print("Duplicate function name for description detected: " + f.name + " for node " + node.name)
				comment_descriptions[f.name] = documentation[f.name]

			# append function
			valid_functions.append(f)
	var valid_names : Array = valid_functions.map(func(d): return d["name"])

	# Add function definitions, keep old data and preserve order
	var result : Array[ToolcallFunctionDefinition] = []
	for name_to_add : String in valid_names:
		# Do we already have something?
		var definition : ToolcallFunctionDefinition = null
		# Try to find existing
		for existing_definition in tool_calls_function_definitions.definitions:
			if existing_definition.name == name_to_add:
				definition = existing_definition
				break
		if !definition:
			definition = ToolcallFunctionDefinition.new()
			# enabled by default
			definition.enabled = true
		definition.name = name_to_add
		definition.description_comment = "" if !comment_descriptions.has(definition.name) else comment_descriptions[definition.name]
		result.append(definition)

	# Set the value
	tool_calls_function_definitions.definitions = result
	tool_calls_function_definitions.notify_property_list_changed()
	pass

func _ready() -> void:
	if Engine.is_editor_hint():
		_validate_tool_call_definitions()
		if character_config and !character_config.property_list_changed.is_connected(notify_property_list_changed):
			character_config.property_list_changed.connect(notify_property_list_changed)
		if chat_config and !chat_config.property_list_changed.is_connected(notify_property_list_changed):
			chat_config.property_list_changed.connect(notify_property_list_changed)
		return
	_queue_process_timer = Timer.new()
	self.add_child(_queue_process_timer)
	_queue_process_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_queue_process_timer.wait_time = chat_config.queue_check_interval_seconds
	_queue_process_timer.one_shot = false
	_queue_process_timer.timeout.connect(_process_chat_api)
	_queue_process_timer.start()

	# Clear history if we're NOT auto storing it
	# no actually don't do this we might do it manually...
	#if not auto_store_conversation_history:
		#clear_conversation_history()

	if use_player2_selected_character:
		_update_selected_character_from_endpoint()
	else:
		_on_entry_load_conversation_or_greet()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# TODO override setter to avoid process func update
	_queue_process_timer.wait_time = chat_config.queue_check_interval_seconds

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	# Before we leave, store our conversation history.
	if auto_store_conversation_history:
		save_conversation_history()
