## Speech To Text processing using the Player2 launcher
class_name Player2STT
extends Node

@export var enabled : bool = true
@export var config : Player2Config = Player2Config.new()
@export var timeout : float = 10
@export var accept_empty_input : bool = false

var listening: bool = false:
	set(value):
		if listening != value:
			listening = value
			if listening:
				listening_started.emit()
			else:
				listening_stopped.emit()

var waiting_on_reply: bool = false:
	set(value):
		if waiting_on_reply != value:
			waiting_on_reply = value
			if waiting_on_reply:
				reply_wait_started.emit()
			else:
				reply_wait_stopped.emit()

signal stt_received(message : String)

signal listening_started
signal listening_stopped

signal reply_wait_started
signal reply_wait_stopped

func start_stt() -> void:
	if not enabled:
		return
	print("(")
	if listening:
		return
	if waiting_on_reply:
		return
	listening = true
	var req = Player2Schema.STTStartRequest.new()
	req.timeout = timeout
	Player2API.stt_start(config, req, func(fail_code):
		listening = false
	)

func stop_stt() -> void:
	print(")")
	if not listening:
		return
	if waiting_on_reply:
		return
	listening = false
	waiting_on_reply = true
	Player2API.stt_stop(config, func(reply):
		if enabled:
			if reply.has('text'):
				var message : String = reply.text
				if not message.is_empty() or accept_empty_input:
					print("STT GOT: \"" + message + "\"")
					stt_received.emit(message)
			else:
				print("STT invalid reply!")
				print(JSON.stringify(reply))
		waiting_on_reply = false,
	func(fail_code):
		waiting_on_reply = false
	)
