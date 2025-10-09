class_name Player2EditorPopupHelper

static func add_editor_ui(ui : Node) -> void:
	var root : Control = EditorInterface.get_base_control()
	root.add_child(ui)

static func create_editor_clientid_popup() -> void:
	if !Engine.is_editor_hint():
		return

	var dialogue := AcceptDialog.new()
	dialogue.dialog_text = \
"""
You must configure the client_id first in Project Settings from the Player2 Developer Dashboard.

1) Go to the developer dashboard and create a game
2) Copy the game's client id (check the main dashboard page again)
3) In Godot, go to Project -> Project Settings -> General
4) Scroll down to Player2 on the left side and input the client_id
"""

	dialogue.close_requested.connect(func():
		dialogue.queue_free()
	)

	dialogue.ok_button_text = "Close"

	dialogue.add_button("Help Getting Client Id").pressed.connect(func():
		OS.shell_open(Player2APIConfig.grab().endpoint_webpage.client_id_help)
	)

	dialogue.add_button("Go to Dashboard").pressed.connect(func():
		OS.shell_open(Player2APIConfig.grab().endpoint_webpage.developer_dashboard)
	)

	add_editor_ui(dialogue)
	dialogue.popup_centered()
