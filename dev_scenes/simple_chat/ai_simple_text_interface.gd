extends Node

@export var button : Button
@export var text : TextEdit
@export var chat : Label

@export var poke_button : Button
@export var deselect_on_send : bool

@export var player2_stt : Player2STT

const stt_keycode : int = KEY_TAB

signal text_sent(text : String)
signal poked

func _ready() -> void:
	button.pressed.connect(send)
	# Make enter key send a message too
	text.gui_input.connect(
		func(event : InputEvent):
			if event is InputEventKey:
				# STT key, ignore and just type
				if event.keycode == stt_keycode:
					text.text = ""
					text.accept_event()
					text.release_focus()
				# Enter: submit shortcut
				if event.pressed and event.keycode == KEY_ENTER:
					text.accept_event()
					send()
	)
	if poke_button:
		poke_button.pressed.connect(func(): poked.emit())
	
	if player2_stt:
		# Pass the message from stt upwards
		player2_stt.stt_received.connect(_send)

func _send(text : String) -> void:
	append_line_user(text)
	text_sent.emit(text)
	self.text.text = ""
	if deselect_on_send:
		self.text.release_focus()

func send() -> void:
	_send(text.text)

func append_line_user(line : String) -> void:
	print("got user: " + line)
	if chat:
		chat.text += "User: " + line + "\n"

func append_line_agent(line : String) -> void:
	print("got agent: " + line)
	if chat:
		chat.text += "Agent: " + line + "\n"

# STT 

var _stt_press : bool
func process_stt(event : InputEvent) -> void:
	if event is InputEventKey:
		# STT key
		if event.keycode == stt_keycode:
			var stt_press = event.pressed
			if stt_press != _stt_press:
				if stt_press:
					player2_stt.start_stt()
				else:
					player2_stt.stop_stt()
				_stt_press = stt_press

func _input(event: InputEvent) -> void:
	if player2_stt:
		process_stt(event)
