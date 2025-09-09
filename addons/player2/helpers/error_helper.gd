extends Node


signal error(error : String)

@onready var error_container : Node = $ScrollContainer/VBoxContainer

func send_error(error : String, also_print : bool = true) -> void:
	self.error.emit(error)
	if also_print:
		print(error)
	if Player2APIConfig.grab().error_log_ui:
		# TODO: Better toast system
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = "Player2 ERROR: " + error
		if error_container:
			error_container.add_child(label)
