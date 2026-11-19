extends Node

const Hub = preload("res://src/ui/hub.gd")
const RaceSession = preload("res://src/race/race_session.gd")
const RaceHUD = preload("res://src/ui/race_hud.gd")
const GameAudio = preload("res://src/audio/game_audio.gd")

@onready var game_state := get_node("/root/GameState")

var hub: Control
var race: Node3D
var hud: Control
var audio: Node
var active_ticket: Dictionary
var active_sector := "garage"
var race_settled := false
var race_result: Dictionary


func _ready() -> void:
	get_tree().quit_on_go_back = false
	audio = GameAudio.new()
	add_child(audio)
	_apply_settings()
	audio.set_scene(active_sector)
	hub = Hub.new()
	hub.race_requested.connect(begin_race)
	hub.sector_changed.connect(_on_sector_changed)
	hub.ui_cue.connect(_on_ui_cue)
	add_child(hub)
	var interrupted: Dictionary = game_state.resume_race()
	if interrupted.get("ok", false):
		call_deferred("_launch_race", interrupted.race)


func begin_race(event_id: String, npc_id: String, wager: int, pink: bool) -> void:
	if is_instance_valid(race):
		return
	call_deferred("_open_race", event_id, npc_id, wager, pink)


func _open_race(event_id: String, npc_id: String, wager: int, pink: bool) -> void:
	if is_instance_valid(race):
		return
	var response: Dictionary = game_state.start_race(event_id, npc_id, wager, pink)
	if not response.get("ok", false):
		hub.show_notice(str(response.get("message", "Evento indisponível.")))
		audio.play_cue("error")
		return
	_launch_race(response.race)


func _launch_race(ticket: Dictionary) -> void:
	if is_instance_valid(race):
		return
	active_ticket = ticket
	race_settled = false
	race_result = {}
	_apply_settings()
	hub.hide()
	hub.process_mode = Node.PROCESS_MODE_DISABLED
	audio.set_vehicle(active_ticket.car)
	audio.set_scene("race")
	race = RaceSession.new()
	race.configure(active_ticket.event, active_ticket.car, active_ticket.opponents, active_ticket.settings)
	race.race_finished.connect(_on_race_finished)
	add_child(race)

	var interface := CanvasLayer.new()
	interface.layer = 10
	race.add_child(interface)
	hud = RaceHUD.new()
	hud.configure(active_ticket, race.course_outline())
	hud.controls_changed.connect(race.set_controls)
	hud.pause_changed.connect(_set_race_paused)
	hud.reset_requested.connect(race.reset_player)
	hud.camera_requested.connect(race.cycle_camera)
	hud.withdraw_requested.connect(race.abort)
	hud.return_requested.connect(_close_race)
	hud.retry_requested.connect(_settle_race)
	interface.add_child(hud)
	race.telemetry_changed.connect(_on_telemetry)


func _on_telemetry(data: Dictionary) -> void:
	if not is_instance_valid(hud):
		return
	hud.update_telemetry(data)
	audio.update_race(data)


func _on_race_finished(result: Dictionary) -> void:
	if not race_result.is_empty():
		return
	race_result = result
	race_result["race_id"] = active_ticket.id
	audio.set_paused(false)
	_settle_race()


func _settle_race() -> void:
	if race_settled or race_result.is_empty():
		return
	var receipt: Dictionary = game_state.finish_race(race_result)
	race_settled = bool(receipt.get("ok", false))
	audio.play_cue(("win" if race_result.get("won", false) else "lose") if race_settled else "error")
	hud.show_results(race_result, receipt)


func _close_race() -> void:
	if not is_instance_valid(race) or not race_settled:
		return
	race.queue_free()
	race = null
	hud = null
	active_ticket = {}
	hub.process_mode = Node.PROCESS_MODE_INHERIT
	if hub.has_method("refresh"):
		hub.refresh()
	hub.show()
	audio.set_scene(active_sector)


func _set_race_paused(paused: bool) -> void:
	if is_instance_valid(race) and not race_settled:
		race.set_paused(paused)
		audio.set_paused(paused)


func _on_sector_changed(sector: String) -> void:
	active_sector = sector
	if not is_instance_valid(race):
		audio.set_scene(active_sector)


func _on_ui_cue(cue: String) -> void:
	_apply_settings()
	audio.play_cue(cue)


func _apply_settings() -> void:
	var settings: Dictionary = game_state.settings
	var master := float(settings.get("master_volume", 0.85)) if settings.get("sound", true) else 0.0
	audio.set_levels(master, float(settings.get("music_volume", 0.45)), float(settings.get("effects_volume", 0.80)))
	var mobile_default := 30 if OS.has_feature("mobile") else 60
	Engine.max_fps = int(settings.get("fps", settings.get("fps_limit", mobile_default)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if is_instance_valid(hud) and not race_settled:
			hud.request_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(hub):
		if race_settled and is_instance_valid(race):
			_close_race()
		elif is_instance_valid(hud):
			hud.request_pause()
		elif not hub.back():
			get_tree().quit()
