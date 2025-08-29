@tool
## Text 2 Speech node for Player 2 API
class_name Player2TTS
extends Node

@export var config : Player2TTSConfig = Player2TTSConfig.new()

## Text to speech audio. If not present, an audio player will be created.
@export var tts_audio_player : Node:
	set(value):
		if value and !(value is AudioStreamPlayer or value is AudioStreamPlayer2D or value is AudioStreamPlayer3D):
			printerr("Invalid TTS audio player provided. Must be an AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D.")
			return
		if tts_audio_player:
			tts_audio_player.finished.disconnect(_on_tts_finished)
		tts_audio_player = value
		if tts_audio_player:
			tts_audio_player.finished.connect(_on_tts_finished)

signal tts_began
signal tts_ended

var _tts_playing


func _on_tts_finished() -> void:
	if _tts_playing:
		tts_ended.emit()
		_tts_playing = false

func speak(message : String, voice_ids : Array[String] = []) -> void:
	# Cancel previous TTS
	stop()

	if message.is_empty():
		printerr("Empty message to TTS provided. Not speaking.")
		return

	var req := Player2Schema.TTSRequest.new()
	req.text = message
	req.speed = config.tts_speed
	req.play_in_app = false
	# Thankfully these are just defaults, characters override this
	req.voice_gender = Player2TTSConfig.Gender.find_key(config.tts_default_gender).to_lower()
	req.voice_language = Player2TTSConfig.Language.find_key(config.tts_default_language)
	req.audio_format = "mp3" # TODO: Customize? Enum?
	req.voice_ids = voice_ids

	Player2API.tts_speak(req, func(data):
		_tts_playing = true
		tts_began.emit()
		var audio_data : String = data["data"]
		# Web endpoint returns data:audio/mp3;base64, at the start so remove that...
		var first_comma = audio_data.find(",")
		if first_comma != -1:
			audio_data = audio_data.substr(first_comma + 1)
		# Validation
		if !(tts_audio_player is AudioStreamPlayer or tts_audio_player is AudioStreamPlayer2D or tts_audio_player is AudioStreamPlayer3D):
			#printerr("Invalid TTS audio player provided. Must be an AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D. Creating default.")
			tts_audio_player = null
		# Ensure TTS audio player exists
		if !tts_audio_player:
			tts_audio_player = AudioStreamPlayer.new()
			add_child(tts_audio_player)
		# Decode raw bytes to audio stream
		var decoded_bytes = Marshalls.base64_to_raw(audio_data)
		var stream : AudioStream = AudioStreamMP3.new()
		stream.set_data(decoded_bytes)
		# Play this stream
		tts_audio_player.stream = stream
		tts_audio_player.play()
	)

## Stops TTS
func stop() -> void:
	if not Player2API.using_web():
		Player2API.tts_stop()
	if tts_audio_player:
		tts_audio_player.stop()
	_on_tts_finished()

func _property_can_revert(property: StringName) -> bool:
	return property == "config"

func _property_get_revert(property: StringName) -> Variant:
	if property == "config":
		return Player2TTSConfig.new()
	return null
