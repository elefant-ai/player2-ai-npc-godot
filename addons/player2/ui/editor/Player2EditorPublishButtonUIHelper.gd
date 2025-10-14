class_name Player2EditorPublishButtonUIHelper

const TOPBAR_PUBLISH_BUTTON_UI_SCENE = "res://addons/player2/ui/editor/Player2EditorPublishButtonUI.tscn"

var _custom_editor_ui : Control = null

func _on_button_pressed() -> void:
	var client_id : String = ProjectSettings.get_setting("player2/client_id", "")
	if client_id.is_empty():
		Player2EditorPopupHelper.create_editor_clientid_popup()
		return

	var export_zip_path := Player2ExportHelper.export_web_zip()

	var dialogue := AcceptDialog.new()
	dialogue.dialog_text = \
"""
Build created.
Please go to the website below and copy the build ZIP file over from the directory below.
"""

	dialogue.close_requested.connect(func():
		dialogue.queue_free()
	)

	dialogue.ok_button_text = "Close"

	dialogue.add_button("Open Export Directory").pressed.connect(func():
		OS.shell_open(export_zip_path.get_base_dir())
	)

	dialogue.add_button("Go to Player2 Upload").pressed.connect(func():
		var upload_url : String = Player2APIConfig.grab().endpoint_webpage.upload_game
		upload_url = upload_url.replace("{client_id}", ProjectSettings.get_setting("player2/client_id", ""))
		OS.shell_open(upload_url)
	)

	Player2EditorPopupHelper.add_editor_ui(dialogue)
	dialogue.popup_centered()

func create_button() -> void:
	delete_button()

	var top_bar = Player2EditorUIHelper.get_editor_top_bar()
	#var button : Button = Button.new()
	#button.text = "Publish to Player2"
	var ui_scene = load(TOPBAR_PUBLISH_BUTTON_UI_SCENE)
	if not ui_scene:
		printerr("Could not open publish button UI scene. Make sure that the player2 plugin is under the root `addons` folder.")
		return
	var button = ui_scene.instantiate() as Button

	# Move to publishing button to the left of the play buttons
	top_bar.add_child(button)
	top_bar.move_child(button, button.get_index() - 2)
	_custom_editor_ui = button
	
	button.pressed.connect(_on_button_pressed)

func delete_button() -> void:
	if _custom_editor_ui:
		_custom_editor_ui.queue_free()
		_custom_editor_ui = null
