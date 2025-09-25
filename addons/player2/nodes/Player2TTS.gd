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

var _tts_cancel_flag

var _queue_start_frames : int = 0
var _queued_data : PackedByteArray = []

var _test_data : PackedByteArray = []

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
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
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
	if spb.size() % 2 != 0:
		printerr("Packed byte array data is not divisible by 2, implying it's not 16 bit: ", spb.size())
	for i in range(spb.size() / 2):
		var v_s16 = spb.decode_s16(i * 2)
		var p = inverse_lerp(-32768, 32767, v_s16)
		var v_float = lerp(-1.0, 1.0, p)
		result.push_back(Vector2(v_float, v_float))
	return result
func _stereo_float_frames_to_byte_array(arr: PackedVector2Array) -> PackedByteArray:
	var pb := StreamPeerBuffer.new()
	pb.big_endian = false

	var result : PackedByteArray = []
	for i in range(arr.size()):
		var v2 := arr.get(i)
		var f_avg = (v2.x + v2.y) * 0.5
		var s16 : int = int(round(clamp(f_avg, -1, 1) * 32767))
		pb.put_16(s16)
	return pb.data_array


func _update_audio_frames() -> void:

	var player = _get_audio_stream_player(self, tts_audio_player)
	
	if not player or not player.playing:
		return

	var playback : AudioStreamGeneratorPlayback = player.get_stream_playback()

	if not playback:
		return

	var can_push_frames := playback.get_frames_available()
	# one frame reads 2 bytes s16
	var data_frames_available := int(floor(_queued_data.size() * 0.5)) - _queue_start_frames
	var pushing_frames := int(min(can_push_frames, data_frames_available))

	# If we can't push nothing, do nothings
	if pushing_frames == 0:
		return

	var queue_start_bytes := _queue_start_frames * 2
	var pushing_bytes := pushing_frames * 2

	#print("ASDF PUSH [", queue_start_bytes, ", ", queue_start_bytes + pushing_bytes, "). Total queue size: ", _queued_data.size(), ", available bytes to push: ", (can_push_frames * 2))
	var data_to_process = _queued_data.slice(queue_start_bytes, queue_start_bytes + pushing_bytes)

	_test_data.append_array(data_to_process)
	#print("PUSHING ", pushing_bytes, " = ", data_to_process.size(), " sliced from ", queued_data.size(), ": ", can_push_frames, " vs ", data_frames_available)

	var vector2_buffer := _byte_array_to_stereo_float_frames(data_to_process)
	playback.push_buffer(vector2_buffer)

	_queue_start_frames += pushing_frames

	#if 2 * _queue_start_frames >= _queued_data.size():
		# We ran out


func _process(delta: float) -> void:
	_update_audio_frames()

func speak(message : String, voice_ids : Array[String] = []) -> void:
	# Cancel previous TTS
	stop()
	# don't actually stop it tho
	_tts_cancel_flag = false

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

		_queue_start_frames = 0

		#print("ASDF 0")
		_queued_data.clear()

		# TEST only
		_test_data.clear()

		Player2API.tts_speak_stream(req, func(data):
			var raw_data = data["data"] if data is Dictionary else data

			# Initialize audio
			if not _tts_playing:
				_tts_playing = true
				tts_audio_player = _get_audio_stream_player(self, tts_audio_player)
				var generator_stream = AudioStreamGenerator.new()
				generator_stream.buffer_length = 4 # seconds
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

			# Append data
			_queued_data.append_array(data)

			# TODO: Check if cancelled
			return not _tts_cancel_flag
			,
			func():
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
	_tts_cancel_flag = true
	_on_tts_finished()

func _property_can_revert(property: StringName) -> bool:
	return property == "config"

func _property_get_revert(property: StringName) -> Variant:
	if property == "config":
		return Player2TTSConfig.new()
	return null
