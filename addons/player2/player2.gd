@tool
class_name Player2
extends EditorPlugin

const ASYNC_HELPER_AUTOLOAD_NAME = "Player2AsyncHelper"
const ASYNC_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/async_helper.gd"

const ERROR_HELPER_AUTOLOAD_NAME = "Player2ErrorHelper"
const ERROR_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/error_helper.tscn"

const WEB_HELPER_AUTOLOAD_NAME = "Player2WebHelper"
const WEB_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/web_helper.gd"

const AUTH_HELPER_AUTOLOAD_NAME = "Player2AuthHelper"
const AUTH_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/auth_helper.gd"

const API_SOURCE_HELPER_AUTOLOAD_NAME = "Player2APISourceHelper"
const API_SOURCE_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/Player2APISource.tscn"

const API_HELPER_AUTOLOAD_NAME = "Player2API"
const API_HELPER_AUTOLOAD_PATH = "res://addons/player2/helpers/api.gd"

const OPENING_PROMPT_UI_SCENE = "res://addons/player2/ui/opening/Player2OpeningUI.tscn"

var _editor_ui_helper := Player2EditorPublishButtonUIHelper.new()

func _enter_tree() -> void:

	# Custom UI
	if _editor_ui_helper:
		_editor_ui_helper.create_button()

	# Settings
	# Client ID
	if not ProjectSettings.has_setting("player2/client_id"):
		var default : String = ""
		ProjectSettings.set_setting("player2/client_id", default)
		ProjectSettings.add_property_info({
			"name": "player2/client_id",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE
		})
	# Hide opening prompt (don't show again)
	if not ProjectSettings.has_setting("player2/hide_opening_prompt"):
		ProjectSettings.set_setting("player2/hide_opening_prompt", false)
		ProjectSettings.add_property_info({
			"name": "player2/hide_opening_prompt",
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE
		})

	# TODO: This breaks godot/crashes the loading, so if this ever gets fixed add it back in since it's so nice!!
	# API settings
	#if not ProjectSettings.has_setting("player2/api"):
		#var default : string = Player2APIConfig.new()
		#ProjectSettings.set_setting("player2/api", default)
		#ProjectSettings.add_property_info({
			#"name": "player2/api",
			#"type": TYPE_STRING,
			#"hint": PROPERTY_HINT_RESOURCE_TYPE,
			#"hint_string": "Player2APIConfig"
		#})
	#elif !ProjectSettings.get("player2/api"):
		#ProjectSettings.set_setting("player2/api", Player2APIConfig.new())

	# game_key is Deprecated
	if ProjectSettings.has_setting("player2/game_key"):
		ProjectSettings.clear("player2/game_key")
	ProjectSettings.set_as_basic("player2/client_id", true)
	ProjectSettings.set_as_basic("player2/hide_opening_prompt", true)
	#ProjectSettings.set_as_basic("player2/api", true)

	add_autoload_singleton(ASYNC_HELPER_AUTOLOAD_NAME, ASYNC_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(ERROR_HELPER_AUTOLOAD_NAME, ERROR_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(API_SOURCE_HELPER_AUTOLOAD_NAME, API_SOURCE_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(WEB_HELPER_AUTOLOAD_NAME, WEB_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(AUTH_HELPER_AUTOLOAD_NAME, AUTH_HELPER_AUTOLOAD_PATH)
	add_autoload_singleton(API_HELPER_AUTOLOAD_NAME, API_HELPER_AUTOLOAD_PATH)

	# Initialization of the plugin goes here.
	add_custom_type("Player2AINPC", "Player2AINPC", preload("nodes/Player2AINPC.gd"), preload("p2.svg"))
	add_custom_type("Player2STT", "Player2STT", preload("nodes/Player2STT.gd"), preload("p2.svg"))
	add_custom_type("Player2TTS", "Player2TTS", preload("nodes/Player2TTS.gd"), preload("p2.svg"))
	add_custom_type("Player2AIChatCompletion", "Player2AIChatCompletion.gd", preload("nodes/Player2AIChatCompletion.gd"), preload("p2.svg"))
	add_custom_type("Player2AIImageGeneration", "Player2AIImageGeneration", preload("nodes/Player2AIImageGeneration.gd"), preload("p2.svg"))

	_possibly_run_opening_prompt()


func _exit_tree() -> void:

	# Custom UI
	if _editor_ui_helper:
		_editor_ui_helper.delete_button()

	# Settings
	ProjectSettings.clear("player2/client_id")
	ProjectSettings.clear("player2/hide_opening_prompt")
	#ProjectSettings.clear("player2/api", true)

	remove_autoload_singleton(API_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(AUTH_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(WEB_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(API_SOURCE_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(ERROR_HELPER_AUTOLOAD_NAME)
	remove_autoload_singleton(ASYNC_HELPER_AUTOLOAD_NAME)

	# Clean-up of the plugin goes here.
	remove_custom_type("Player2AINPC")
	remove_custom_type("Player2STT")
	remove_custom_type("Player2TTS")
	remove_custom_type("Player2AIChatCompletion")
	remove_custom_type("Player2AIImageGeneration")


func _enable_plugin() -> void:
	pass
func _disable_plugin() -> void:
	pass


func _open_scene_template(template_scene : PackedScene):
	# print("OPENING SCENE: ", template_scene.resource_path)
	EditorInterface.open_scene_from_path(template_scene.resource_path, true)

func _possibly_run_opening_prompt():
	if ProjectSettings.get_setting("player2/hide_opening_prompt", false):
		return

	var ui_scene = load(OPENING_PROMPT_UI_SCENE)
	if not ui_scene:
		printerr("Could not open starting UI scene. Make sure that the player2 plugin is under the root `addons` folder.")
		return

	var opening_ui = ui_scene.instantiate() as Player2OpeningUI

	#print("Opening deafult prompt")

	var w := Window.new()
	w.always_on_top = true
	w.borderless = true
	# TODO: Transparent doesn't do anything. Sticking to square for now.
	w.transparent_bg = true
	w.transparent = true
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	w.add_child(opening_ui)
	EditorInterface.popup_dialog_centered(w, Vector2i(640, 480))
	w.close_requested.connect(func():
		w.queue_free()
		)

	opening_ui.closed.connect(func(dont_show_again : bool):
		if dont_show_again:
			ProjectSettings.set_setting("player2/hide_opening_prompt", true)
		w.queue_free()
		)
	opening_ui.template_opened.connect(func(template_scene : PackedScene):
		_open_scene_template(template_scene)
		w.queue_free()
	)
