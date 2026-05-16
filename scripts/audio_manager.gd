extends Node

@export_group("SFX Files")
@export var sfx_click: AudioStream
@export var sfx_knob_turn: AudioStream
@export var sfx_switch_toggle: AudioStream
@export var sfx_lever_move: AudioStream
@export var sfx_panel_toggle: AudioStream
@export var sfx_collision: AudioStream
@export var sfx_breaker_trip: AudioStream
@export var sfx_sling_beep: AudioStream

@export_group("Alarm Files")
@export var alarm_o2: AudioStream
@export var alarm_temp: AudioStream
@export var alarm_storm: AudioStream

@export_group("Gameplay")
@export var sfx_engine_loop: AudioStream

@export_group("Combat SFX")
@export var sfx_player_fire_1: AudioStream
@export var sfx_player_fire_2: AudioStream
@export var sfx_player_fire_3: AudioStream
@export var sfx_player_fire_4: AudioStream
@export var sfx_explosion_1: AudioStream
@export var sfx_explosion_2: AudioStream
@export var sfx_explosion_3: AudioStream
@export var sfx_explosion_4: AudioStream
@export_range(0.0, 1.0) var combat_volume: float = 1.0
@export var sfx_enemy_fire: AudioStream
@export var sfx_explosion_boss: AudioStream
@export var sfx_player_hit: AudioStream
@export var sfx_player_death: AudioStream
@export var sfx_barrel_roll: AudioStream
@export var sfx_missile_fire: AudioStream
@export var sfx_laser_hum: AudioStream
@export var sfx_laser_overheat: AudioStream
@export var sfx_turret_fire: AudioStream
@export var sfx_level_complete: AudioStream
@export var sfx_level_failed: AudioStream
@export var sfx_upgrade_select: AudioStream

var _sfx_pool: Array[AudioStreamPlayer] = []
var _player_fire_pool: Array[AudioStream] = []
var _explosion_pool: Array[AudioStream] = []
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

func _ready() -> void:
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)
	_player_fire_pool = _build_pool([sfx_player_fire_1, sfx_player_fire_2, sfx_player_fire_3, sfx_player_fire_4])
	_explosion_pool = _build_pool([sfx_explosion_1, sfx_explosion_2, sfx_explosion_3, sfx_explosion_4])
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

func _build_pool(streams: Array[AudioStream]) -> Array[AudioStream]:
	var result: Array[AudioStream] = []
	for s in streams:
		if s != null:
			result.append(s)
	return result

func _play_combat_sfx(pool: Array[AudioStream], fallback: Callable) -> void:
	var stream: AudioStream = null
	if pool.size() > 0:
		stream = pool[randi() % pool.size()]
	else:
		stream = fallback.call()
	for p: AudioStreamPlayer in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(combat_volume)
			p.play()
			return
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	add_child(p)
	_sfx_pool.append(p)
	p.stream = stream
	p.volume_db = linear_to_db(combat_volume)
	p.play()

func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
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
	_play_sfx(sfx_click if sfx_click else _make_click_tone())

func play_knob_turn() -> void:
	_play_sfx(sfx_knob_turn if sfx_knob_turn else _make_tone(300.0, 0.06, 0.3, "noise"))

func play_switch_toggle() -> void:
	_play_sfx(sfx_switch_toggle if sfx_switch_toggle else _make_click_tone())

func play_lever_move() -> void:
	_play_sfx(sfx_lever_move if sfx_lever_move else _make_tone(200.0, 0.1, 0.3, "saw"))

func play_panel_toggle() -> void:
	_play_sfx(sfx_panel_toggle if sfx_panel_toggle else _make_tone(400.0, 0.15, 0.3, "sine"))

func play_collision() -> void:
	_play_sfx(sfx_collision if sfx_collision else _make_collision_tone())

func play_breaker_trip() -> void:
	_play_sfx(sfx_breaker_trip if sfx_breaker_trip else _make_breaker_tone())

func play_alarm(type: String) -> void:
	if _alarm_active:
		return
	var alarm_map: Dictionary = {"o2": alarm_o2, "temp": alarm_temp, "storm": alarm_storm}
	var freq_map: Dictionary = {"o2": 880.0, "temp": 660.0, "storm": 1200.0}
	var s: AudioStream = alarm_map.get(type, null)
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
	_play_sfx(sfx_sling_beep if sfx_sling_beep else _make_tone(660.0, 0.1, 0.4, "sine"))

func engine_start() -> void:
	if _engine_active:
		return
	if sfx_engine_loop:
		_engine_player.stream = sfx_engine_loop
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

func _make_player_fire_tone() -> AudioStreamWAV:
	return _make_tone(880.0, 0.08, 0.4, "square")

func _make_enemy_fire_tone() -> AudioStreamWAV:
	return _make_tone(440.0, 0.1, 0.35, "square")

func _make_explosion_tone() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples: int = int(sample_rate * 0.4)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 5.0)
		var val: float = randf_range(-1.0, 1.0) * 0.6
		val += sin(t * 120.0 * TAU) * 0.3 * exp(-t * 3.0)
		val *= env
		var ival: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _make_explosion_boss_tone() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples: int = int(sample_rate * 0.8)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 3.0)
		var val: float = randf_range(-1.0, 1.0) * 0.7
		val += sin(t * 80.0 * TAU) * 0.4 * exp(-t * 2.0)
		val += sin(t * 200.0 * TAU) * 0.2 * exp(-t * 4.0)
		val *= env
		var ival: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _make_player_hit_tone() -> AudioStreamWAV:
	return _make_tone(200.0, 0.15, 0.5, "noise")

func _make_player_death_tone() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples: int = int(sample_rate * 0.6)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 4.0)
		var freq: float = lerpf(600.0, 100.0, t / 0.6)
		var val: float = sin(t * freq * TAU) * 0.4
		val += randf_range(-1.0, 1.0) * 0.3 * exp(-t * 6.0)
		val *= env
		var ival: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _make_barrel_roll_tone() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples: int = int(sample_rate * 0.3)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(sample_rate)
		var freq: float = lerpf(400.0, 1200.0, t / 0.3)
		var val: float = sin(t * freq * TAU) * 0.35
		val *= 1.0 - t / 0.3
		var ival: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _make_missile_fire_tone() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples: int = int(sample_rate * 0.25)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(sample_rate)
		var freq: float = lerpf(800.0, 200.0, t / 0.25)
		var val: float = sin(t * freq * TAU) * 0.4
		val += randf_range(-1.0, 1.0) * 0.15 * exp(-t * 10.0)
		val *= 1.0 - t / 0.25
		var ival: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _make_laser_hum_tone() -> AudioStreamWAV:
	return _make_tone(500.0, 0.15, 0.25, "sine")

func _make_laser_overheat_tone() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples: int = int(sample_rate * 0.3)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(sample_rate)
		var freq: float = lerpf(1000.0, 150.0, t / 0.3)
		var val: float = sin(t * freq * TAU) * 0.5
		val *= 1.0 - t / 0.3
		var ival: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _make_turret_fire_tone() -> AudioStreamWAV:
	return _make_tone(660.0, 0.06, 0.3, "square")

func _make_level_complete_tone() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples: int = int(sample_rate * 0.6)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var notes: Array = [523.0, 659.0, 784.0, 1047.0]
	var note_len: int = samples / notes.size()
	for n in range(notes.size()):
		for i in range(note_len):
			var t: float = float(i) / float(sample_rate)
			var env: float = 1.0 - float(n * note_len + i) / float(samples)
			var val: float = sin(t * notes[n] * TAU) * 0.4 * env
			var idx: int = n * note_len + i
			if idx < samples:
				var ival: int = clampi(int(val * 32767.0), -32768, 32767)
				data.encode_s16(idx * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _make_level_failed_tone() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples: int = int(sample_rate * 0.8)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var notes: Array = [400.0, 350.0, 300.0, 200.0]
	var note_len: int = samples / notes.size()
	for n in range(notes.size()):
		for i in range(note_len):
			var t: float = float(i) / float(sample_rate)
			var env: float = 1.0 - float(n * note_len + i) / float(samples)
			var val: float = sin(t * notes[n] * TAU) * 0.4 * env
			var idx: int = n * note_len + i
			if idx < samples:
				var ival: int = clampi(int(val * 32767.0), -32768, 32767)
				data.encode_s16(idx * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _make_upgrade_select_tone() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var samples: int = int(sample_rate * 0.2)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(sample_rate)
		var val: float = sin(t * 880.0 * TAU) * 0.3
		val += sin(t * 1320.0 * TAU) * 0.2
		val *= 1.0 - t / 0.2
		var ival: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, ival)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func play_player_fire() -> void:
	_play_combat_sfx(_player_fire_pool, _make_player_fire_tone)

func play_enemy_fire() -> void:
	_play_sfx(sfx_enemy_fire if sfx_enemy_fire else _make_enemy_fire_tone())

func play_explosion() -> void:
	_play_combat_sfx(_explosion_pool, _make_explosion_tone)

func play_explosion_boss() -> void:
	_play_sfx(sfx_explosion_boss if sfx_explosion_boss else _make_explosion_boss_tone())

func play_player_hit() -> void:
	_play_sfx(sfx_player_hit if sfx_player_hit else _make_player_hit_tone())

func play_player_death() -> void:
	_play_sfx(sfx_player_death if sfx_player_death else _make_player_death_tone())

func play_barrel_roll() -> void:
	_play_sfx(sfx_barrel_roll if sfx_barrel_roll else _make_barrel_roll_tone())

func play_missile_fire() -> void:
	_play_sfx(sfx_missile_fire if sfx_missile_fire else _make_missile_fire_tone())

func play_laser_hum() -> void:
	_play_sfx(sfx_laser_hum if sfx_laser_hum else _make_laser_hum_tone())

func play_laser_overheat() -> void:
	_play_sfx(sfx_laser_overheat if sfx_laser_overheat else _make_laser_overheat_tone())

func play_turret_fire() -> void:
	_play_sfx(sfx_turret_fire if sfx_turret_fire else _make_turret_fire_tone())

func play_level_complete() -> void:
	_play_sfx(sfx_level_complete if sfx_level_complete else _make_level_complete_tone())

func play_level_failed() -> void:
	_play_sfx(sfx_level_failed if sfx_level_failed else _make_level_failed_tone())

func play_upgrade_select() -> void:
	_play_sfx(sfx_upgrade_select if sfx_upgrade_select else _make_upgrade_select_tone())

func set_combat_volume(value: float) -> void:
	combat_volume = clampf(value, 0.0, 1.0)

func get_combat_volume() -> float:
	return combat_volume
