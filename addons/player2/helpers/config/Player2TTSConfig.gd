@tool
class_name Player2TTSConfig
extends Resource

enum Gender {MALE, FEMALE, OTHER}
enum Language { en_US, en_GB, ja_JP, zh_CN, es_ES, fr_FR, hi_IN, it_IT, pt_BR }

## If true, will stream audio as we receive it.
## Otherwise will grab the entire audio at once.
@export var stream : bool = false

## Experiment with this. Setting to false (use Mp3) is generally better but wav is a good fallback.
@export var use_wav : bool = false

## Speed Scale (1 is default)
@export var tts_speed : float = 1
## Default TTS language (overriden if `Player2 Selected Character` is enabled)
@export var tts_default_language : Language = Language.en_US
## Default TTS gender (overriden if `Player2 Selected Character` is enabled)
# switching to male because for some reason female US doesn't work?
@export var tts_default_gender : Gender = Gender.MALE
## Voice ID. Either click the button below to use the launcher to select a voice id, or
## go to https://api.player2.game/v1/tts/voices and copy a voice_id
@export var voice_id : String = ""

@export_tool_button("Select Voice ID") var open_voice_selector_window = _open_voice_selector_window

func _open_voice_selector_window():
	assert(Engine.is_editor_hint())

	var endpoint_local := Player2LocalEndpointConfig.new()
	var endpoing_website := Player2WebpageEndpointConfig.new()
	var path = endpoint_local.path("tts_voices")

	var fail := func(content, code):
		assert(Engine.is_editor_hint())
		var d := ConfirmationDialog.new()
		# Silly godot build issue
		# EditorInterface.popup_dialog_centered(d, Vector2i(480, 120))
		var editor_interface = Engine.get_singleton("EditorInterface")
		editor_interface.popup_dialog_centered(d, Vector2i(480, 120))
		d.close_requested.connect(func():
			d.queue_free()
			)
		d.dialog_text = "Please install and have the Player2 Launcher running in the background to view voice IDs:"
		d.ok_button_text = "Download Player2 Launcher"
		d.cancel_button_text = "Cancel"
		d.get_ok_button().pressed.connect(func():
			OS.shell_open(endpoing_website.download_player2_launcher)
		)
		d.get_cancel_button().pressed.connect(func():
			d.queue_free()
		)

	Player2WebHelper.request(path, HTTPClient.Method.METHOD_GET, "", [], func(body, code, headers):
		print("tts voices got code ", code)
		if code != 200:
			fail.call("Failed to get a request locally, is the player2 launcher installed properly?", code)
			return
		var d := JSON.parse_string(body)
		var voices : Array = d["voices"]

		var ui_scene = load("res://addons/player2/ui/VoiceIdSelectorUI.tscn")
		if not ui_scene:
			printerr("Could not open selector. Make sure that the player2 plugin is under the root `addons` folder.")
			return

		var selector_ui = ui_scene.instantiate() as Player2VoiceIdSelectorUI

		var w := Window.new()
		# w.always_on_top = true
		# this is better
		w.transient = true
		w.exclusive = true
		w.add_child(selector_ui)

		# Silly godot build issue
		# EditorInterface.popup_dialog_centered(w, Vector2i(640, 480))
		var editor_interface = Engine.get_singleton("EditorInterface")
		editor_interface.popup_dialog_centered(w, Vector2i(640, 480))
		w.close_requested.connect(func():
			w.queue_free()
			)

		selector_ui.voice_id_selected.connect(func(new_voice_id : String):
			voice_id = new_voice_id
			print("new selected: ", voice_id)
		)
		selector_ui.voice_id_previewed.connect(func(voice_id : String, preview_text : String):
			var speak_path = endpoint_local.path("tts_speak")
			var req := {}
			req.voice_ids = []
			req.audio_format = "mp3"
			req.voice_ids.assign([voice_id])
			req.text = preview_text
			req.play_in_app = false
			req.speed = 1
			var req_string := JSON.stringify(req)
			Player2WebHelper.request(speak_path, HTTPClient.Method.METHOD_POST, req_string, ['Content-Type: application/json'], func(body, code, headers):
				# Speak
				Player2TTS.speak_raw_data(selector_ui, JSON.parse_string(body)["data"], null, false)
				)
			)

		for voice : Dictionary in voices:
			var voice_id : String = voice["id"]
			var name : String = voice["name"]
			var language : String = voice["language"]
			var gender : String = voice["gender"]

			var text = name + " (" + language + ", " + gender + ")"
			selector_ui.add_button(text, voice_id),
		fail,
		0.5
	)
