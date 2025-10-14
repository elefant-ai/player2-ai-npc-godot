@tool
## Text 2 Speech node for Player2 API
class_name Player2TTS
extends Node

# TODO: Audio streaming implementation is a mess.
# If ever I need to do a redesign, I would probably create a separate node to
# accept audio mp3/wav data as a stream and to play it.

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

# Streaming
var _stream_index : int = 0
var _queue_start_frames : int = 0
var _queued_data : PackedByteArray = []
var _skip_last_skips : int = 0
var _skip_frames_counter : int = 0
var _empty_mp3_frames : int = 0
var _first_mp3_received : bool

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

static func speak_raw_data(parent : Node, audio_data : Variant, tts_audio_player : Node, use_wav : bool = false, playback_pos : float = -1) -> Node:
	audio_data = _filter_raw_data(audio_data)
	tts_audio_player = _get_audio_stream_player(parent, tts_audio_player)
	# Decode raw bytes to audio stream

	var decoded_bytes = audio_data

	var stream
	if use_wav:
		stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 48000 / 2 # WTF 48000 is incorrect??
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		stream.set_data(decoded_bytes)
	else:
		stream = AudioStreamMP3.load_from_buffer(decoded_bytes)

	# Play this stream
	tts_audio_player.stream = stream
	if playback_pos <= 0:
		tts_audio_player.play()
	else:
		tts_audio_player.play(playback_pos)

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

func _update_audio_frames_stream_mp3_pull(player : Variant) -> void:
	if _queued_data.size() == 0:
		print("mp3 EMPTY")
		# _empty_mp3_frames += 1
		if _empty_mp3_frames > 20:
			_on_tts_finished()
		return
	_empty_mp3_frames = 0

	# CONTINUING does not work, mp3 can't accurately seek resulting in obvious skips.

	#var should_continue = player.playing and player.get_stream_playback() != null
	#if should_continue:
		#var prev_position = player.get_playback_position()
		#speak_raw_data(self, _queued_data, player, false, prev_position)
		#print("mp3 CONTINUE: at ", prev_position, " -> ", player.get_playback_position(), ": ", _queued_data.size())
		#_last_mp3_pull_playback_position = prev_position
	#else:
	# new

	# print("mp3 NEW: ", _queued_data.size())
	speak_raw_data(self, _queued_data, player, false)
	_queued_data.clear()
	_first_mp3_received = true

func _update_audio_frames_stream_mp3() -> void:
	# This is only for streaming
	if not config.stream:
		return

	if not _tts_playing:
		return

	# We only do this for mp3.
	if config.use_wav:
		return

	var player = _get_audio_stream_player(self, tts_audio_player)

	# var done : bool = not player.playing or not player.get_stream_playback()
	# if not done:
	# 	var playback : AudioStreamMP3 = player.stream as AudioStreamMP3
	# 	if playback:
	# 		print("mp3 PLAY: ", player.get_playback_position(), " / ",  playback.get_length())

	if not player.playing or player.get_stream_playback() == null:
		# Start after 16KB buffer has data
		if _first_mp3_received or _queued_data.size() > 16384:
			_update_audio_frames_stream_mp3_pull(player)

func _update_audio_frames_stream_wav() -> void:

	# This is only for streaming
	if not config.stream:
		return

	if not _tts_playing:
		return

	# We only do this for wav. Mp3 does its own thing.
	if not config.use_wav:
		return

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

	# SKIP end check
	# After we stop getting data and get some skips, we're done.
	var skips = playback.get_skips()
	if skips != _skip_last_skips:
		var skips_since_last = skips - _skip_last_skips
		_skip_last_skips = skips
		# If we're not waiting for data, count how much we skipped.
		if not _tts_waiting_for_data:
			_skip_frames_counter += skips_since_last
			if _skip_frames_counter > 100: # magic number
				_on_tts_finished()

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
	_update_audio_frames_stream_wav()
	_update_audio_frames_stream_mp3()

func speak(message : String, voice_ids : Array[String] = [], voice_instructions : String = "") -> void:
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
	req.advanced_voice = Player2Schema.TTSRequestAdvancedVoice.new()
	req.advanced_voice.instructions = voice_instructions

	if config.stream:
		# Stream.
		_tts_waiting_for_data = true
		_tts_playing = false

		# Stream index
		var our_stream_index := _stream_index

		_queue_start_frames = 0
		_first_mp3_received = false

		_skip_frames_counter = 0

		print("STREAM START")
		_queued_data.clear()

		# TEST only
		_test_data.clear()

		Player2API.tts_speak_stream(req,
			func(data):
				if _stream_index != our_stream_index:
					# stop, no longer at our valid index.
					return false

				var raw_data = data["data"] if data is Dictionary else data

				_skip_frames_counter = 0

				# Initialize audio
				if not _tts_playing:
					_tts_playing = true
					tts_began.emit()
					tts_audio_player = _get_audio_stream_player(self, tts_audio_player)
					
					# if wav, we initialize a generator
					# otherwise we just keep popping audio streams...
					if config.use_wav:
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
				# print("STREAM GOT ", data.size())
				_queued_data.append_array(data)

				# We keep going
				return true,
			func():
				if _stream_index == our_stream_index:
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
	# old closures with invalid stream index will stop
	_stream_index += 1
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
