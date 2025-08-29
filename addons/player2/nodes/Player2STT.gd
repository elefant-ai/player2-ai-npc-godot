@tool
## Speech To Text processing using the Player2 API
class_name Player2STT
extends Node

@export var enabled : bool = true
@export var local_timeout : float = 10
## How long to wait from the last message to consider the message to be complete.
@export var leftover_receive_wait_time : float = 0.5
## We will never wait longer than this after releasing the STT button
@export var release_max_wait_time : float = 1.5

@export var audio_stream : AudioStream
"autoplay"
const AUDIO_CAPTURE_BUS = "Player2STTAudioCaptureBus"

var _audio_stream_player : AudioStreamPlayer
var _audio_capture_effect : AudioEffectCapture
var _audio_capture_buffer : StreamPeerBuffer
var _audio_stream_transcript : String = ""

var _audio_stream_running : bool
var _audio_stream_leftover_timer : Timer
var _audio_stream_release_timer : Timer
var _audio_stream_leftover_timer_triggered : bool = false

#var _audio_stream_playback : AudioStreamPlayback

## Whether we're currently listening for speech
var listening: bool = false:
	set(value):
		if listening != value:
			listening = value
			if listening:
				listening_started.emit()
			else:
				listening_stopped.emit()

## Whether we're waiting on the system to return text
var waiting_on_reply: bool = false:
	set(value):
		if waiting_on_reply != value:
			waiting_on_reply = value
			if waiting_on_reply:
				reply_wait_started.emit()
			else:
				reply_wait_stopped.emit()

## When an STT message is received
signal stt_received(message : String)
## When an STT message has failed
signal stt_failed(message : String, code : int)

## When we start listening for speech
signal listening_started
## When we stop listening for speech
signal listening_stopped

## When we start waiting for the reply text for SST
signal reply_wait_started
## When we finish waiting for the reply text for SST
signal reply_wait_stopped

## Begin listening for speech. If already listening, do nothing.
func start_stt() -> void:
	if not enabled:
		return
	if listening:
		return
	if waiting_on_reply:
		return
	
	if !Player2API.established_api_connection():
		print("Tried doing STT to early, establishing a connection first.")
		Player2API.establish_connection()
		return

	_start_stt()
	listening = true

## Stop listening for speech. Will query STT to receive text from received speech.
func stop_stt() -> void:
	if not listening:
		return
	if waiting_on_reply:
		return

	if !Player2API.established_api_connection():
		print("Tried doing STT to early, establishing a connection first.")
		Player2API.establish_connection()
		return

	_stop_stt()
	listening = false
	waiting_on_reply = true

# Internals

func _using_web() -> bool:
	return Player2API.using_web()

func _start_stt() -> void:
	if !enabled:
		return
	if _using_web():
		#printerr("Web API for STT is WIP")
		#return
		_start_stt_web()
	else:
		_start_stt_local()

func _stop_stt() -> void:
	if _using_web():
		#printerr("Web API for STT is WIP")
		#return
		_stop_stt_web()
	else:
		_stop_stt_local()

# Local

func _start_stt_local() -> void:
	var req = Player2Schema.STTStartRequest.new()
	req.timeout = local_timeout
	Player2API.stt_start(
		req,
		func(body, fail_code):
			listening = false
	)
func _stop_stt_local() -> void:
	Player2API.stt_stop(func(reply):
		if enabled:
			if reply.has('text'):
				var message : String = reply.text
				if not message.is_empty():
					print("STT GOT: \"" + message + "\"")
					stt_received.emit(message)
			else:
				print("STT invalid reply!")
				print(JSON.stringify(reply))
		waiting_on_reply = false,
	func(body, fail_code):
		waiting_on_reply = false
	)

# Web

var _socket : WebSocketPeer
var _stream_opened : bool

## Ensures that the audio bus is created with a capture effect
func _ensure_audio_bus_exists() -> AudioEffectCapture:
	var index := AudioServer.get_bus_index(AUDIO_CAPTURE_BUS)
	if index == -1:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, AUDIO_CAPTURE_BUS)
		# Capture (to read)
		var capture_effect := AudioEffectCapture.new()
		AudioServer.add_bus_effect(index, capture_effect, 0)
		# Amplify (to mute)
		var amplify_effect = AudioEffectAmplify.new()
		amplify_effect.volume_db = -100000
		AudioServer.add_bus_effect(index, amplify_effect, 1)
		return capture_effect
	return AudioServer.get_bus_effect(index, 0)

func _start_stt_web() -> void:
	if _audio_stream_running:
		print("Duplicate STT detected, cancelling the old one.")

	_audio_stream_leftover_timer.stop()
	_audio_stream_leftover_timer_triggered = false
	
	_audio_stream_release_timer.stop()
	
	_audio_stream_transcript = ""

	# If we haven't authenticated yet, don't do anything.
	if !Player2API.established_api_connection():
		print("Failed to establish connection. Establishing...")
		Player2API.establish_connection(func():
			print("Established!")
			)
		return

	if _socket:
		_socket.close()
		_socket = null

	var sample_rate : int = int(AudioServer.get_mix_rate())
	_socket = Player2API.stt_stream_socket(sample_rate)
	_stream_opened = false

	if !audio_stream:
		audio_stream = AudioStreamMicrophone.new()
	if audio_stream is AudioStreamMicrophone:
		# Make sure setting is active
		if !ProjectSettings.get_setting("audio/driver/enable_input"):
			Player2ErrorHelper.send_error("Need to enable audio input in settings for microphone (Project -> Project Settings -> Audio -> Driver -> enable input)")

	# Start recording now and adding to buffer queue
	if audio_stream:
		_audio_stream_running = true
		# Initialize the bus w/ capture effect
		_audio_capture_effect = _ensure_audio_bus_exists()
		# Set the bus to our stream player and PLAY
		if _audio_stream_player:
			_audio_stream_player.stop()
		else:
			_audio_stream_player = AudioStreamPlayer.new()
			add_child(_audio_stream_player)
		_audio_stream_player.stream = audio_stream
		_audio_stream_player.bus = AUDIO_CAPTURE_BUS
		_audio_stream_player.play()
		if _audio_capture_buffer:
			_audio_capture_buffer.clear()
		_audio_capture_buffer = StreamPeerBuffer.new()

func _stop_stt_web() -> void:
	if _audio_stream_running:
		# stop sending
		# but keep receiving for a bit... until we haven't received something in a bit
		_audio_stream_player.stop()
		_audio_stream_running = false
	_audio_stream_release_timer.start(release_max_wait_time)

func _ready() -> void:
	_audio_stream_leftover_timer = Timer.new()
	_audio_stream_leftover_timer.one_shot = true
	add_child(_audio_stream_leftover_timer)
	_audio_stream_leftover_timer.timeout.connect(func(): _audio_stream_leftover_timer_triggered = true)
	_audio_stream_release_timer = Timer.new()
	_audio_stream_release_timer.one_shot = true
	add_child(_audio_stream_release_timer)
	_audio_stream_release_timer.timeout.connect(func():
		_socket_complete()
		)

func _process(delta: float) -> void:
	_possibly_close_socket(_socket)
	_poll_socket(_socket)
	_process_socket(_socket)
	_send_socket(_socket)

func _possibly_close_socket(socket : WebSocketPeer) -> void:
	if socket and !enabled:
		socket.close()

func _poll_socket(socket : WebSocketPeer) -> void:
	if !socket:
		return
	socket.poll()

func _stereo_float_frames_to_byte_array(frames_stereo : PackedVector2Array, spb : StreamPeerBuffer) -> void:
	# 16 bit signed int
	#var spb := StreamPeerBuffer.new()
	spb.big_endian = false  # WAV/PCM typical little-endian
	for fr in frames_stereo:
		var v_float := fr.x if abs(fr.x) > abs(fr.y) else fr.y
		var v := int(round(clamp(v_float, -1.0, 1.0) * 32767.0))
		spb.put_16(v)
	#return spb.data_array

func _read_audio_frames() -> void:
	if audio_stream and _audio_capture_effect:
		# 50 MS at a time is the sweet spot

		var available := _audio_capture_effect.get_frames_available()
		if !available:
			return

		var target_duration = 50.0 / 1000.0
		var sample_rate = AudioServer.get_mix_rate()
		var max_frames = ceil(sample_rate * target_duration)

		var frames_to_cap = int(min(max_frames, available))
		var frames_stereo : PackedVector2Array = _audio_capture_effect.get_buffer(frames_to_cap)  # each Vector2 is (L,R) in [-1.0, 1.0]
		# convert to mono 16 bit signed int
		_stereo_float_frames_to_byte_array(frames_stereo, _audio_capture_buffer)


func _send_socket(socket : WebSocketPeer) -> void:
	if !socket:
		return
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	# TODO: Test this out
	#if !_stream_opened:
		#return

	_read_audio_frames()

	# TODO: Buffer, send over while we can
	var bytes : PackedByteArray = _audio_capture_buffer.data_array
	if bytes.size():
		#print("sending ", bytes.size())

		# A print just to roughly see the strength of the thing
		#var i16 := (bytes[1] << 8) + bytes[0]
		#if (i16 & (1 << (16 - 1))) != 0:
			#i16 = i16 - (1 << 16)
		#print(i16)
		#var b : Control = $"../Control/ColorRect"
		#b.position.y = i16 * 0.01

		var err = socket.send(bytes)
		if err != OK:
			print("SOCKET SEND ERROR:", err)
	_audio_capture_buffer.clear()

func _process_socket(socket : WebSocketPeer) -> void:
	if !socket:
		return

	var state = socket.get_ready_state()

	match state:
		WebSocketPeer.STATE_CONNECTING:
			# wait to open
			pass
		WebSocketPeer.STATE_OPEN:
			while socket.get_available_packet_count():
				var data_raw = socket.get_packet().get_string_from_utf8()
				var data = JSON.parse_string(data_raw)
				#print("Got data from server: ", data_raw)
				if data:
					match data["type"]:
						"open":
							_stream_opened = true
						"message":
							var messages : Array = data["data"]["channel"]["alternatives"]
							if messages.size():
								var highest = messages.reduce(func(max, msg): return msg if msg["confidence"] > max["confidence"] else max)
								if highest:
									_audio_stream_transcript = highest["transcript"].strip_edges()
								# We got a message, reset the leftover timer
								_audio_stream_leftover_timer.start(leftover_receive_wait_time)
								_audio_stream_leftover_timer_triggered = false
							else:
								if _audio_stream_leftover_timer_triggered and _audio_stream_running:
									# We're done!
									_socket_complete()
				#print("ASDF", data, data["type"])
		WebSocketPeer.STATE_CLOSING:
			# wait to close
			pass
		WebSocketPeer.STATE_CLOSED:
			var code = socket.get_close_code()
			print("WebSocket closed with code: %d. Clean: %s" % [code, code != -1])
			if socket == _socket:
				stt_failed.emit("WebSocket closed with code: %d" % code, code)
			_socket = null
		_:
			print("Invalid socket state:", state)

## When the scoket is DONE we're done.
func _socket_complete() -> void:
	if !_audio_stream_transcript.is_empty():
		print("Done. Got", _audio_stream_transcript)
		stt_received.emit(_audio_stream_transcript)
		_audio_stream_transcript = ""
		if _socket:
			_socket.close()
			_socket = null
	waiting_on_reply = false
