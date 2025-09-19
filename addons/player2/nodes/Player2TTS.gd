@tool
## Text 2 Speech node for Player2 API
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
var _tts_waiting_for_data


func _on_tts_finished() -> void:
	if _tts_playing and not _tts_waiting_for_data:
		tts_ended.emit()
		_tts_playing = false

static func _filter_raw_data(audio_data : Variant) -> PackedByteArray:
	if audio_data is PackedByteArray:
		return audio_data
	# Web endpoint returns data:audio/mp3;base64, at the start so remove that...
	var first_comma = audio_data.find(",")
	if first_comma != -1:
		audio_data = audio_data.substr(first_comma + 1)
	# json fuckery :(
	if audio_data.ends_with("\"}"):
		audio_data = audio_data.substr(0, audio_data.length() - 2)

	return Marshalls.base64_to_raw(audio_data)

static func _get_audio_stream_player(parent : Node, tts_audio_player : Node):
	# Validation
	if !(tts_audio_player is AudioStreamPlayer or tts_audio_player is AudioStreamPlayer2D or tts_audio_player is AudioStreamPlayer3D):
		#printerr("Invalid TTS audio player provided. Must be an AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D. Creating default.")
		tts_audio_player = null
	# Ensure TTS audio player exists
	if !tts_audio_player:
		tts_audio_player = AudioStreamPlayer.new()
		parent.add_child(tts_audio_player)
	return tts_audio_player

static func speak_raw_data(parent : Node, audio_data : Variant, tts_audio_player : Node, use_wav : bool = false) -> Node:
	audio_data = _filter_raw_data(audio_data)
	tts_audio_player = _get_audio_stream_player(parent, tts_audio_player)
	# Decode raw bytes to audio stream

	var stream
	if use_wav:
		stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 48000 / 2 # WTF 48000 is incorrect??
	else:
		stream = AudioStreamMP3.new()

	var decoded_bytes = audio_data
	stream.set_data(decoded_bytes)
	# Play this stream
	tts_audio_player.stream = stream
	tts_audio_player.play()

	# JANK to prevent popin for wav
	if use_wav:
		var target_volume = tts_audio_player.volume_db
		tts_audio_player.volume_db = -36
		Player2AsyncHelper.call_timeout(func():
			tts_audio_player.volume_db = target_volume, 0.04
		)

	return tts_audio_player

func _byte_array_to_stereo_float_frames(spb : PackedByteArray) -> PackedVector2Array:
	var result : PackedVector2Array = []
	for i in range(spb.size() / 2):
		var v_s16 = spb.decode_s16(i * 2)
		var v_float = float(v_s16) / 32767.0
		result.push_back(Vector2(v_float, v_float))
	return result


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
	req.audio_format = "wav" if config.use_wav else "mp3" # TODO: Customize? Enum?
	var voice_ids_override : Array[String] = [config.voice_id]
	req.voice_ids = voice_ids if config.voice_id.is_empty() else voice_ids_override

	if config.stream:
		# Stream.
		_tts_waiting_for_data = true
		_tts_playing = false
		#var test_data : PackedVector2Array = []

		var queued_data : PackedVector2Array = []
		var queue_start : int = 0
		#var push_or_queue_data = func(playback : AudioStreamGeneratorPlayback, data : PackedVector2Array):
			#queued_data.append_array(data)
			#var can_push := playback.get_frames_available()
			#if can_push == 0:
				#return
			#if can_push < queued_data.size():
				#playback.push_buffer(queued_data.slice(0, can_push).duplicate())
				#queued_data = queued_data.slice(can_push)
			#else:
				#playback.push_buffer(queued_data.duplicate())
				#queued_data.clear()
		var push_or_queue_data = func(playback : AudioStreamGeneratorPlayback, data : PackedVector2Array):
			queued_data.append_array(data)
			var can_push := playback.get_frames_available()
			if can_push == 0:
				return
			var data_left = queued_data.size() - queue_start
			if data_left == 0:
				return
			if can_push < data_left:
				playback.push_buffer(queued_data.slice(queue_start, queue_start + can_push).duplicate())
				queue_start += can_push
				#queued_data = queued_data.slice(can_push)
			else:
				playback.push_buffer(queued_data.slice(queue_start).duplicate())
				queue_start = queued_data.size()

		# Clear out the buffer while we can
		var update_frame = func():
			push_or_queue_data.call(tts_audio_player.get_stream_playback(), [])

		Player2API.tts_speak_stream(req, func(data):
			var raw_data = data["data"] if data is Dictionary else data

			# Initialize audio
			if not _tts_playing:
				_tts_playing = true
				tts_audio_player = _get_audio_stream_player(self, tts_audio_player)
				var generator_stream = AudioStreamGenerator.new()
				generator_stream.buffer_length = 300 # seconds
				generator_stream.mix_rate = 48000 / 2
				tts_audio_player.stream = generator_stream
				tts_audio_player.play()

				# JANK to prevent popin for wav
				if config.use_wav:
					var target_volume = tts_audio_player.volume_db
					tts_audio_player.volume_db = -36
					Player2AsyncHelper.call_timeout(func():
						tts_audio_player.volume_db = target_volume, 0.04
					)

				get_tree().process_frame.connect(update_frame)


			# Append data
			var playback : AudioStreamGeneratorPlayback = tts_audio_player.get_stream_playback()
			var stereo_data : PackedVector2Array = _byte_array_to_stereo_float_frames(raw_data)

			queued_data.append_array(stereo_data)
			# TODO: Add this back in, the above tests the per-frame pushing 
			#push_or_queue_data.call(playback, stereo_data)

			# TODO: Check if cancelled
			return true
			,
			func():

				if _tts_playing:
					get_tree().process_frame.disconnect(update_frame)

				#_tts_playing = true
				#tts_audio_player = _get_audio_stream_player(self, tts_audio_player)
				#var generator_stream = AudioStreamGenerator.new()
				#generator_stream.mix_rate = 48000 / 2
				#tts_audio_player.stream = generator_stream
				#tts_audio_player.play()
				#var playback : AudioStreamGeneratorPlayback = tts_audio_player.get_stream_playback()
				#print("guh???", playback.get_frames_available())
				#playback.push_buffer(test_data)
				#print("guh???", playback.get_frames_available())
				#_tts_waiting_for_data = false
				#return

				# Allow audio player to finish
				_tts_waiting_for_data = false
		)
	else:
		# no stream, do it all at once.
		Player2API.tts_speak(req, func(data):
			_tts_playing = true
			_tts_waiting_for_data = false
			tts_began.emit()
			tts_audio_player = speak_raw_data(self, data["data"], tts_audio_player, config.use_wav)
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
