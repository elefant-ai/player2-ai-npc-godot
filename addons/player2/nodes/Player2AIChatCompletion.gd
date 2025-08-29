@tool
## Simple chat completion without history. Use to make one time queries!
# TODO: Move redundant logic from Player2AINPC out and into this node
class_name Player2AIChatCompletion
extends Node

## System prompt preceeding all messages
@export_multiline var system_prompt : String = "Answer the user's request cleanly"
## User prompt format. "{message}" just sends the message, but you can customize it if you wish.
@export_multiline var user_prompt_format : String = "{message}"
## Rate at which to check and empty the queue when spamming.
## This will only introduce a delay when chats occur rapidly, so no need to set this to a small value.
@export var queue_check_interval_seconds = 3.0

## Called when our ai agent starts thinking
signal thinking_began
## Called when our ai agent stops thinking and replies
signal thinking_ended
## Called when our ai agent talks
signal chat_received(message : String)
## Called when our ai agent fails a chat
signal chat_failed(body : String, error_code : int)

# Queue

class QueuedChat:
	var req : Player2Schema.ChatCompletionRequest
	var on_complete : Callable

var _queue : Array[QueuedChat] = []
var _queue_process_timer : Timer

var thinking: bool:
	set(value):
		if thinking != value:
			thinking = value
			if thinking:
				thinking_began.emit()
			else:
				thinking_ended.emit()

func _process_queue() -> void:
	if thinking:
		return
	if _queue.is_empty():
		return

	# FIFO
	var callback := _queue.pop_front()
	thinking = true

	Player2API.chat(callback.req,
		func(result):
			thinking = false
			if result.choices.size() != 0:
				var reply = result.choices.get(0).message.content
				chat_received.emit(reply)
				if callback.on_complete:
					callback.on_complete.call(reply)
				# done, good.
				return
			var msg = "Invalid reply: " + JsonClassConverter.class_to_json_string(result) 
			printerr(msg)
			chat_failed.emit(msg, -1234)
			,
		func(body, code):
			thinking = false
			chat_failed.emit(body, code)
	)

## Send a message to the agent
## Reply can be parsed via `chat_received` or `on_complete`
func chat(message : String, on_complete : Callable = Callable()) -> void:
	var request := Player2Schema.ChatCompletionRequest.new()

	# System message
	var system_msg := Player2Schema.Message.new()
	system_msg.role = "system"
	system_msg.content = system_prompt

	# Get all previous messages as a log...
	var user_msg = Player2Schema.Message.new()
	user_msg.role = "user"
	user_msg.content = user_prompt_format.replace("{message}", message)

	var req_messages = [system_msg, user_msg]
	request.messages.assign(req_messages)

	var callback := QueuedChat.new()
	callback.req = request
	callback.on_complete = on_complete

	_queue.push_back(callback)

	_process_queue()

func _process(delta: float) -> void:
	# onValidate
	if Engine.is_editor_hint():
		return
	_queue_process_timer.wait_time = queue_check_interval_seconds

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_queue_process_timer = Timer.new()
	self.add_child(_queue_process_timer)
	_queue_process_timer.wait_time = queue_check_interval_seconds
	_queue_process_timer.one_shot = false
	_queue_process_timer.timeout.connect(_process_queue)
	_queue_process_timer.start()
