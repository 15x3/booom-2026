extends Node

var _sfx_pool: Array[AudioStreamPlayer] = []
var _engine_player: AudioStreamPlayer = null
var _engine_gen: AudioStreamGenerator = null
var _engine_playback: AudioStreamGeneratorPlayback = null
var _engine_active: bool = false
var _engine_phase: float = 0.0
var _engine_freq: float = 60.0
var _engine_target_freq: float = 60.0

var _alarm_player: AudioStreamPlayer = null
var _alarm_active: bool = false
var _alarm_type: String = ""

var _audio_dir: String = "res://assets/audio/"

func _ready() -> void:
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)
	_engine_player = AudioStreamPlayer.new()
	_engine_player.bus = "Master"
	_engine_player.volume_db = -8.0
	add_child(_engine_player)
	_alarm_player = AudioStreamPlayer.new()
	_alarm_player.bus = "Master"
	_alarm_player.volume_db = -6.0
	add_child(_alarm_player)

func _process(_delta: float) -> void:
	if _engine_active and _engine_playback:
		_engine_freq = lerpf(_engine_freq, _engine_target_freq, 0.05)
		var frames_available: int = _engine_playback.get_frames_available()
		var buf := PackedVector2Array()
		buf.resize(frames_available)
		var sample_rate: float = _engine_gen.mix_rate
		for i in range(frames_available):
			_engine_phase += _engine_freq / sample_rate * TAU
			var val: float = sin(_engine_phase) * 0.3
			val += sin(_engine_phase * 2.0) * 0.1
			val += sin(_engine_phase * 0.5) * 0.05
			buf[i] = Vector2(val, val)
		_engine_playback.push_buffer(buf)

func _play_sfx(stream: AudioStream) -> void:
	for p: AudioStreamPlayer in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	add_child(p)
	_sfx_pool.append(p)
	p.stream = stream
	p.play()

func _try_file(name: String) -> AudioStream:
	var path: String = _audio_dir + name + ".ogg"
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _make_tone(freq: float, duration: float, volume: float = 0.5, wave_type: String = "sine") -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = 1.0 - (float(i) / float(samples))
		env = minf(env * 4.0, 1.0) * (1.0 - maxf((float(i) / float(samples) - 0.8) * 5.0, 0.0))
		var val: float = 0.0
		match wave_type:
			"sine":
				val = sin(t * freq * TAU)
			"square":
				val = 1.0 if sin(t * freq * TAU) >= 0.0 else -1.0
			"noise":
				val = randf_range(-1.0, 1.0)
			"saw":
				val = fmod(t * freq, 1.0) * 2.0 - 1.0
		val *= env * volume
		var ival: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _make_click_tone() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples: int = int(sample_rate * 0.05)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 60.0)
		var val: float = sin(t * 800.0 * TAU) * 0.6
		val += randf_range(-0.4, 0.4) * exp(-t * 80.0)
		val *= env
		var ival: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _make_collision_tone() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples: int = int(sample_rate * 0.2)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 12.0)
		var val: float = randf_range(-1.0, 1.0) * 0.5
		val += sin(t * 150.0 * TAU) * 0.3 * exp(-t * 8.0)
		val += sin(t * 400.0 * TAU) * 0.2 * exp(-t * 15.0)
		val *= env
		var ival: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _make_breaker_tone() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples: int = int(sample_rate * 0.3)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 8.0)
		var crackle: float = randf_range(-1.0, 1.0) * (1.0 if randf() > 0.3 else 0.0)
		var val: float = sin(t * 2000.0 * TAU) * 0.3 * randf_range(0.0, 1.0)
		val += crackle * 0.5
		val *= env
		var ival: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _make_alarm_tone(freq: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var beep_samples: int = int(sample_rate * 0.12)
	var pause_samples: int = int(sample_rate * 0.08)
	var cycle: int = beep_samples + pause_samples
	var total: int = cycle * 6
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in range(total):
		var in_cycle: int = i % cycle
		var val: float = 0.0
		if in_cycle < beep_samples:
			var t: float = float(in_cycle) / float(sample_rate)
			val = sin(t * freq * TAU) * 0.5
		var ival: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func play_click() -> void:
	var s: AudioStream = _try_file("click")
	if s == null:
		s = _make_click_tone()
	_play_sfx(s)

func play_knob_turn() -> void:
	var s: AudioStream = _try_file("knob_turn")
	if s == null:
		s = _make_tone(300.0, 0.06, 0.3, "noise")
	_play_sfx(s)

func play_switch_toggle() -> void:
	var s: AudioStream = _try_file("switch_toggle")
	if s == null:
		s = _make_click_tone()
	_play_sfx(s)

func play_lever_move() -> void:
	var s: AudioStream = _try_file("lever_move")
	if s == null:
		s = _make_tone(200.0, 0.1, 0.3, "saw")
	_play_sfx(s)

func play_panel_toggle() -> void:
	var s: AudioStream = _try_file("panel_toggle")
	if s == null:
		s = _make_tone(400.0, 0.15, 0.3, "sine")
	_play_sfx(s)

func play_collision() -> void:
	var s: AudioStream = _try_file("collision")
	if s == null:
		s = _make_collision_tone()
	_play_sfx(s)

func play_breaker_trip() -> void:
	var s: AudioStream = _try_file("breaker_trip")
	if s == null:
		s = _make_breaker_tone()
	_play_sfx(s)

func play_alarm(type: String) -> void:
	if _alarm_active:
		return
	var file_map: Dictionary = {"o2": "alarm_o2", "temp": "alarm_temp", "storm": "alarm_storm"}
	var s: AudioStream = _try_file(file_map.get(type, ""))
	var freq_map: Dictionary = {"o2": 880.0, "temp": 660.0, "storm": 1200.0}
	if s == null:
		s = _make_alarm_tone(freq_map.get(type, 880.0))
	_alarm_player.stream = s
	_alarm_player.play()
	_alarm_active = true
	_alarm_type = type
	_alarm_player.finished.connect(_on_alarm_finished, CONNECT_ONE_SHOT)

func stop_alarm(type: String = "") -> void:
	if type != "" and _alarm_type != type:
		return
	if _alarm_player.playing:
		_alarm_player.stop()
	_alarm_active = false
	_alarm_type = ""

func _on_alarm_finished() -> void:
	_alarm_active = false
	_alarm_type = ""

func play_sling_beep() -> void:
	var s: AudioStream = _try_file("sling_beep")
	if s == null:
		s = _make_tone(660.0, 0.1, 0.4, "sine")
	_play_sfx(s)

func engine_start() -> void:
	if _engine_active:
		return
	var s: AudioStream = _try_file("engine_loop")
	if s != null:
		_engine_player.stream = s
		_engine_player.play()
		_engine_active = true
		return
	_engine_gen = AudioStreamGenerator.new()
	_engine_gen.mix_rate = 22050
	_engine_player.stream = _engine_gen
	_engine_player.play()
	_engine_playback = _engine_player.get_stream_playback()
	_engine_active = true
	_engine_phase = 0.0

func engine_stop() -> void:
	_engine_active = false
	_engine_player.stop()
	_engine_playback = null

func engine_set_throttle(level: int) -> void:
	var freq_map: Array = [0.0, 60.0, 80.0, 110.0]
	if level < 0 or level >= freq_map.size():
		return
	_engine_target_freq = freq_map[level]
	if level > 0 and not _engine_active:
		engine_start()
	elif level == 0 and _engine_active:
		engine_stop()
