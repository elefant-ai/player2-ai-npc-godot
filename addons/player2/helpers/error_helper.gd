extends Node


signal error(error : String)

@onready var error_container : Node = $ScrollContainer/VBoxContainer

func send_error(error : String) -> void:
	self.error.emit(error)
	if Player2APIConfig.grab().error_log_ui:
		var label = Label.new()
		label.text = "Player2 ERROR: " + error
		if error_container:
			error_container.add_child(label)
