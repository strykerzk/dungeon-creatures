extends Node

const MAX_DURATION: float = 1.5
const BUS_NAME: String = "MicCapture"

var sample_rate: int = 0
var _capture_effect: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null
var _recording: bool = false
var _elapsed: float = 0.0
var _bus_index: int = -1

signal recording_stopped(stream: AudioStreamWAV)
signal recording_tick(seconds_remaining: float)

func _ready() -> void:
	sample_rate = AudioServer.get_mix_rate()
	print("[AudioRecorder] Capture rate: ", sample_rate, " Hz")
	# Request mic permission (relevant on macOS, Android, iOS)
	if OS.get_name() in ["macOS", "Android", "iOS"]:
		if not OS.request_permission("RECORD_AUDIO"):
			push_warning("[AudioRecorder] Microphone permission not granted.")
	_setup_capture_bus()
	_setup_mic_player()

func _setup_capture_bus() -> void:
	var existing_index = AudioServer.get_bus_index(BUS_NAME)
	if existing_index != -1:
		# Bus already exists — recover the reference instead of returning
		_bus_index = existing_index
		_capture_effect = AudioServer.get_bus_effect(_bus_index, 0) as AudioEffectCapture
		return
	
	AudioServer.add_bus()
	_bus_index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(_bus_index, BUS_NAME)
	AudioServer.set_bus_mute(_bus_index, true)
	_capture_effect = AudioEffectCapture.new()
	_capture_effect.buffer_length = MAX_DURATION + 0.5
	AudioServer.add_bus_effect(_bus_index, _capture_effect)

func _setup_mic_player() -> void:
	_mic_player = AudioStreamPlayer.new()
	var mic_stream = AudioStreamMicrophone.new()
	_mic_player.stream = mic_stream
	_mic_player.bus = BUS_NAME
	add_child(_mic_player)

func start_recording() -> bool:
	if _recording: return false
	if not _capture_effect:
		push_error("[AudioRecorder] Capture effect is null — bus setup failed.")
		return false
	print("[AudioRecorder] Bus index: ", _bus_index,
		  " | Effect: ", _capture_effect,
		  " | Mic player bus: ", _mic_player.bus)
	_capture_effect.clear_buffer()
	_mic_player.play()
	_recording = true
	_elapsed = 0.0
	return true

func stop_recording() -> void:
	if not _recording:
		return
	_recording = false
	_mic_player.stop()
	var stream = _build_wav_stream()
	recording_stopped.emit(stream)

func _process(delta: float) -> void:
	if not _recording:
		return
	_elapsed += delta
	recording_tick.emit(max(0.0, MAX_DURATION - _elapsed))
	if _elapsed >= MAX_DURATION:
		stop_recording()

func _build_wav_stream() -> AudioStreamWAV:
	var available: int = _capture_effect.get_frames_available()
	# Cap to what we actually recorded — avoids reading stale buffered frames
	var expected: int = int(sample_rate * _elapsed)
	var frames_to_read: int = min(available, expected)
	
	print("[AudioRecorder] Frames available: ", available,
		  " | Reading: ", frames_to_read,
		  " | Expected: ", expected)
		
	var frames: PackedVector2Array = _capture_effect.get_buffer(frames_to_read)
	var byte_data: PackedByteArray = PackedByteArray()
	
	for frame in frames:
		var sample: float = (frame.x + frame.y) * 0.5
		var int_sample: int = int(clamp(sample, -1.0, 1.0) * 32767)
		byte_data.append(int_sample & 0xFF)
		byte_data.append((int_sample >> 8) & 0xFF)
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = byte_data
	return wav

static func wav_to_bytes(stream: AudioStreamWAV) -> PackedByteArray:
	if stream == null:
		return PackedByteArray()
	return stream.data

static func bytes_to_wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	if data.is_empty():
		return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
