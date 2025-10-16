@tool
extends Control

@export var button : Button
@export var text : TextEdit
@export var chat_container : Control
@export var scroll_container : ScrollContainer
@export var thinking : CanvasItem

@export var focus_on_show : bool = true
@export var deselect_on_send : bool = false
@export var show_history : bool = true

@export var player2_stt : Player2STT

const stt_keycode : int = KEY_TAB

signal text_sent(text : String)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	#for x in ["HELLO!", "aSDasd aDS asd asD ASD aDs aSD asD aSD ASD asdAADAS ", "sda !# K!@R( QSKD( akdi0 ak))", "fourth line", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"]:
		#_append_line(x)

	if $History:
		$History.visible = show_history

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

	self.visibility_changed.connect(func():
		if visible and focus_on_show:
			text.grab_focus()
	)

	#if player2_stt:
		## Pass the message from stt upwards
		#player2_stt.stt_received.connect(_send)

func _send(text : String) -> void:
	append_line_user(text)
	self.text.text = ""
	if deselect_on_send:
		self.text.release_focus()
	text_sent.emit(text)

func send() -> void:
	_send(text.text)
	
func _append_line(raw_line : String) -> void:
	if chat_container:
		var label := Label.new()
		label.text = raw_line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chat_container.add_child(label)
		label.grab_focus()
		if scroll_container:
			await get_tree().process_frame
			scroll_container.ensure_control_visible(label)

func append_line_user(line : String) -> void:
	print("got user: " + line)
	_append_line("User: " + line)

func append_line_agent(line : String) -> void:
	print("got agent: " + line)
	_append_line("Agent: " + line)

func set_text_input(line : String) -> void:
	text.text = line

func start_thinking() -> void:
	if thinking:
		thinking.show()
func stop_thinking() -> void:
	if thinking:
		thinking.hide()

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
	if Engine.is_editor_hint():
		return
	if visible and player2_stt:
		process_stt(event)
