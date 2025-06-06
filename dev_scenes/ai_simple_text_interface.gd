extends Node

@export var button : Button
@export var text : TextEdit
@export var chat : Label

signal text_sent(text : String)

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

func send() -> void:
	append_line(text.text)
	text_sent.emit(text.text)
	text.text = ""

func append_line(line : String) -> void:
	print("got " + line)
	if chat != null:
		chat.text += line + "\n"
