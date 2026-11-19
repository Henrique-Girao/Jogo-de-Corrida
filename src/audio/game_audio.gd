extends Node

const SILENCE_DB := -80.0
const CUE_VOICES := 6
const SCORE := {
	"garage": preload("res://assets/audio/oficina_0613.ogg"),
	"meet": preload("res://assets/audio/sob_o_viaduto.ogg"),
	"race": preload("res://assets/audio/faixa_de_corte.ogg"),
}
const SCORE_GAIN := {"garage": 0.44, "meet": 0.46, "race": 0.35}
const CUES := {
	"select": preload("res://assets/audio/selecao.wav"),
	"confirm": preload("res://assets/audio/confirma.wav"),
	"error": preload("res://assets/audio/erro.wav"),
	"countdown": preload("res://assets/audio/preparar.wav"),
	"go": preload("res://assets/audio/largada.wav"),
	"win": preload("res://assets/audio/vitoria.wav"),
	"lose": preload("res://assets/audio/derrota.wav"),
	"impact": preload("res://assets/audio/impacto.wav"),
	"shift": preload("res://assets/audio/marcha.wav"),
}
const CUE_GAIN := {
	"select": 0.37, "confirm": 0.46, "error": 0.43, "countdown": 0.72, "go": 0.73,
	"win": 0.67, "lose": 0.63, "impact": 0.78, "shift": 0.40,
}

const MOTOR_LOW = preload("res://assets/audio/motor_baixo.wav")
const MOTOR_LOAD = preload("res://assets/audio/motor_carga.wav")
const TIRE = preload("res://assets/audio/pneu.wav")
const WIND = preload("res://assets/audio/vento.wav")

var _scene := "garage"
var _music_players: Dictionary = {}
var _music_fade := {"garage": 0.0, "meet": 0.0, "race": 0.0}
var _cue_players: Array[AudioStreamPlayer] = []
var _cue_gains: Array[float] = []
var _next_cue := 0
var _motor_low: AudioStreamPlayer
var _motor_load: AudioStreamPlayer
var _tire: AudioStreamPlayer
var _wind: AudioStreamPlayer

var _master_level := 1.0
var _music_level := 0.68
var _effects_level := 0.82
var _paused := false
var _finished := false
var _activity := 0.0
var _engine_range := 1.0
var _engine_character := 0.0
var _rpm := 0.0
var _load := 0.0
var _slip := 0.0
var _speed := 0.0
var _brake := 0.0
var _rpm_target := 0.0
var _load_target := 0.0
var _slip_target := 0.0
var _speed_target := 0.0
var _brake_target := 0.0
var _off_track := false
var _countdown := -1
var _gear := 0
var _impact := 0.0
var _impact_cooldown := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Godot's headless audio driver has no output device and can retain active
	# decoder voices when an automated run exits. Playback probes can opt in.
	if DisplayServer.get_name() == "headless" and "--audio-smoke" not in OS.get_cmdline_user_args():
		set_process(false)
		return
	for section in SCORE:
		var music: AudioStreamOggVorbis = SCORE[section].duplicate()
		music.loop = true
		_music_players[section] = _new_player(music)
	_motor_low = _new_loop(MOTOR_LOW)
	_motor_load = _new_loop(MOTOR_LOAD)
	_tire = _new_loop(TIRE)
	_wind = _new_loop(WIND)
	for voice in CUE_VOICES:
		_cue_players.append(_new_player(null))
		_cue_gains.append(0.0)


func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null


func set_scene(scene: String) -> void:
	var section := scene if SCORE.has(scene) else "garage"
	if section == _scene:
		return
	_scene = section
	_paused = false
	_finished = false
	if section == "race":
		_rpm_target = 0.0
		_load_target = 0.0
		_slip_target = 0.0
		_speed_target = 0.0
		_brake_target = 0.0
		_off_track = false
		_countdown = -1
		_gear = 0
		_impact = 0.0
		_impact_cooldown = 0.0


func set_levels(master: float, music: float, effects: float) -> void:
	_master_level = clampf(master, 0.0, 1.0)
	_music_level = clampf(music, 0.0, 1.0)
	_effects_level = clampf(effects, 0.0, 1.0)
	for voice in _cue_players.size():
		_cue_players[voice].volume_db = _gain_db(_cue_gains[voice] * _master_level * _effects_level)


func set_vehicle(spec: Dictionary) -> void:
	var kind := str(spec.get("kind", ""))
	var torque := float(spec.get("torque", 148))
	_engine_character = clampf((torque - 148.0) / 850.0, 0.0, 0.50)
	match kind:
		"muscle":
			_engine_range = 0.78
			_engine_character *= 0.38
		"super", "euro":
			_engine_range = 1.16
		"jdm", "hot_hatch":
			_engine_range = 1.08
		_:
			_engine_range = 1.0


func set_paused(paused: bool) -> void:
	_paused = paused


func update_race(data: Dictionary) -> void:
	if _scene != "race" or _paused:
		return
	var rpm := float(data.get("rpm", 0.0))
	if rpm > 2.0:
		rpm /= maxf(float(data.get("redline_rpm", 7400.0)), 1000.0)
	_rpm_target = clampf(rpm, 0.0, 1.0)
	_load_target = clampf(float(data.get("throttle", 0.0)), 0.0, 1.0)
	_slip_target = clampf(float(data.get("slip", 0.0)), 0.0, 1.0)
	_speed_target = clampf(float(data.get("speed_kmh", 0.0)) / 265.0, 0.0, 1.0)
	_brake_target = clampf(float(data.get("brake", 0.0)), 0.0, 1.0)
	_off_track = bool(data.get("off_track", false))
	_finished = str(data.get("phase", "")) == "finished"

	var countdown := int(data.get("countdown", -1))
	if countdown != _countdown and countdown >= 0:
		play_cue("go" if countdown == 0 else "countdown")
	_countdown = countdown
	var gear := int(data.get("gear", 0))
	if not _finished and _gear > 0 and gear > 0 and gear != _gear and _speed_target > 0.09:
		play_cue("shift")
	_gear = gear
	var impact := clampf(float(data.get("impact", 0.0)), 0.0, 1.0)
	if _impact_cooldown <= 0.0 and impact > 0.16 and impact > _impact + 0.055:
		_play("impact", sqrt(impact), lerpf(1.12, 0.79, impact))
		_impact_cooldown = 0.22
	_impact = impact


func play_cue(cue: String) -> void:
	_play("select" if cue == "click" else cue)


func _process(delta: float) -> void:
	_impact_cooldown = maxf(_impact_cooldown - delta, 0.0)
	_mix_score(delta)
	_mix_motor(delta)


func _mix_score(delta: float) -> void:
	var music_amp := _master_level * _music_level
	for section in SCORE:
		var player: AudioStreamPlayer = _music_players[section]
		var target := 1.0 if section == _scene and music_amp > 0.001 else 0.0
		if section == "race" and (_paused or _finished):
			target *= 0.42
		var current := move_toward(float(_music_fade[section]), target, delta * 1.42)
		_music_fade[section] = current
		player.volume_db = _gain_db(current * music_amp * float(SCORE_GAIN[section]))
		if target > 0.0 and not player.playing:
			player.play()
		elif current <= 0.0 and player.playing:
			player.stop()


func _mix_motor(delta: float) -> void:
	var mix := _master_level * _effects_level
	var running := _scene == "race" and not _paused and not _finished and mix > 0.001
	_activity = move_toward(_activity, 1.0 if running else 0.0, delta * 4.8)
	_rpm = lerpf(_rpm, _rpm_target, 1.0 - exp(-delta * 16.0))
	_load = lerpf(_load, _load_target, 1.0 - exp(-delta * 13.0))
	_slip = lerpf(_slip, _slip_target, 1.0 - exp(-delta * 12.0))
	_speed = lerpf(_speed, _speed_target, 1.0 - exp(-delta * 9.0))
	_brake = lerpf(_brake, _brake_target, 1.0 - exp(-delta * 12.0))

	var output := mix * _activity
	var pitch := (0.58 + pow(_rpm, 1.10) * 2.24) * _engine_range
	var loaded := clampf(0.22 * _rpm + 0.63 * _load + _engine_character, 0.0, 1.0)
	var engine := lerpf(0.36, 0.67, maxf(_load, _rpm * 0.67)) * output
	var tire_gain := smoothstep(0.12, 0.82, _slip) * smoothstep(0.07, 0.28, _speed) * 0.68
	tire_gain += smoothstep(0.52, 1.0, _brake) * smoothstep(0.24, 0.58, _speed) * 0.15
	if _off_track:
		tire_gain += smoothstep(0.19, 0.58, _speed) * 0.17
	var wind_gain := pow(_speed, 1.4) * 0.39
	_mix_loop(_motor_low, engine * (1.0 - loaded * 0.80), pitch)
	_mix_loop(_motor_load, engine * loaded * 0.94, pitch)
	var tire_pitch := (0.64 if _off_track else 0.84) + _speed * 0.28
	_mix_loop(_tire, output * tire_gain, tire_pitch)
	_mix_loop(_wind, output * wind_gain, 0.87 + _speed * 0.39)


func _mix_loop(player: AudioStreamPlayer, gain: float, pitch: float) -> void:
	player.volume_db = _gain_db(gain)
	player.pitch_scale = pitch
	if gain > 0.001:
		if not player.playing:
			player.play()
	elif player.playing:
		player.stop()


func _play(cue: String, strength := 1.0, pitch := 1.0) -> void:
	if _cue_players.is_empty() or not CUES.has(cue):
		return
	var output := _master_level * _effects_level
	if output < 0.001:
		return
	var voice := _cue_players[_next_cue]
	voice.stop()
	voice.stream = CUES[cue]
	voice.pitch_scale = pitch
	var gain := float(CUE_GAIN[cue]) * strength
	_cue_gains[_next_cue] = gain
	voice.volume_db = _gain_db(gain * output)
	voice.play()
	_next_cue = (_next_cue + 1) % CUE_VOICES


func _new_player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SILENCE_DB
	add_child(player)
	return player


func _new_loop(asset: AudioStreamWAV) -> AudioStreamPlayer:
	var stream: AudioStreamWAV = asset.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * float(stream.mix_rate))
	return _new_player(stream)


func _gain_db(gain: float) -> float:
	return linear_to_db(gain) if gain > 0.0001 else SILENCE_DB
