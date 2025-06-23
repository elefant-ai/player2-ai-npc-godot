extends Node

@export var button : Button
@export var text : TextEdit
@export var chat : Label

@export var poke_button : Button
@export var deselect_on_send : bool

signal text_sent(text : String)
signal poked

func _ready() -> void:
	button.pressed.connect(send)
	# Make enter key send a message too
	text.gui_input.connect(
		func(event : InputEvent):
			if event is InputEventKey:
				if event.pressed and event.keycode == KEY_ENTER:
					text.accept_event()
					send()
	)
	if poke_button:
		poke_button.pressed.connect(func(): poked.emit())

func send() -> void:
	append_line_user(text.text)
	text_sent.emit(text.text)
	text.text = ""
	if deselect_on_send:
		text.release_focus()

func append_line_user(line : String) -> void:
	print("got user: " + line)
	if chat:
		chat.text += "User: " + line + "\n"

func append_line_agent(line : String) -> void:
	print("got agent: " + line)
	if chat:
		chat.text += "Agent: " + line + "\n"
