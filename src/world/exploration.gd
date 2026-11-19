extends Node3D
## District lifecycle and proximity interactions. Race scenes hold the viewport while driving.

signal race_requested(event_id: String, npc_id: String, wager: int, pink: bool)
signal practice_requested(track: String)
signal sector_changed(sector_id: String)
signal ui_cue(cue: String)

const Sector = preload("res://src/world/sector.gd")
const Walker = preload("res://src/world/walk_controller.gd")
const HUD = preload("res://src/ui/exploration_hud.gd")
const Dialogs = preload("res://src/ui/exploration_dialogs.gd")
const Geometry = preload("res://src/world/sector_geometry.gd")
const Ui = preload("res://src/ui/ui_kit.gd")
const Catalog = preload("res://src/domain/catalog.gd")

@onready var _state := get_node("/root/GameState")

var sector: Sector
var player: Walker
var hud: HUD
var dialogs: Dialogs
var sector_id := "garage"
var _target: Sector.Target
var _marker: Label3D
var _interface: CanvasLayer
var _sample_timer := 0.0
var _refresh_pending := false
var _travel_pending := false
var _return_pose: Dictionary = {}


func _ready() -> void:
	sector_id = str(_state.last_sector)
	player = Walker.new()
	player.name = "Jogador"
	add_child(player)
	_marker = Label3D.new()
	_marker.text = "◆"
	_marker.font = Ui.BODY
	_marker.font_size = 29
	_marker.pixel_size = 0.0065
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.modulate = Ui.ACID
	_marker.outline_size = 7
	_marker.outline_modulate = Ui.INK
	_marker.hide()
	add_child(_marker)

	_interface = CanvasLayer.new()
	_interface.layer = 5
	add_child(_interface)
	hud = HUD.new()
	hud.movement_changed.connect(func(vector: Vector2) -> void: player.movement = vector)
	hud.looked.connect(player.orbit)
	hud.interact_pressed.connect(interact)
	hud.settings_pressed.connect(_settings)
	_interface.add_child(hud)
	dialogs = Dialogs.new()
	dialogs.modal_changed.connect(_on_modal)
	dialogs.preview_paint.connect(_paint_preview)
	dialogs.travel_requested.connect(_request_travel)
	dialogs.race_requested.connect(race_requested.emit)
	dialogs.practice_requested.connect(practice_requested.emit)
	dialogs.ui_cue.connect(ui_cue.emit)
	_interface.add_child(dialogs)
	_state.changed.connect(_queue_refresh)
	_load_sector(sector_id)
	_sync_hud()


func suspend() -> void:
	if not is_instance_valid(sector):
		return
	_return_pose = _pose()
	dialogs.close_dialog()
	hud.block_input(true)
	player.reset_input()
	player.controls_enabled = false
	_set_target(null)
	_drop_sector()
	_interface.visible = false
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED


func resume() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	show()
	_load_sector(sector_id, _return_pose)
	_interface.visible = true
	_on_modal(false)
	_sync_hud()
	_update_target()


func show_notice(message: String) -> void:
	dialogs.show_notice(message)


func release_controls() -> void:
	if is_instance_valid(hud):
		hud.clear_input()
	if is_instance_valid(player):
		player.reset_input()


func back() -> void:
	if not dialogs.close_dialog():
		_settings()


func _settings() -> void:
	if is_instance_valid(sector) and not dialogs.is_open() and not _travel_pending:
		dialogs.settings()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_E and not dialogs.is_open():
		interact()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		back()
		get_viewport().set_input_as_handled()


func interact() -> void:
	if _travel_pending or dialogs.is_open() or not is_instance_valid(sector):
		return
	_update_target()
	if _target == null:
		return
	var at := _target.position
	if _target.kind == "paint":
		var active: Node3D = sector.fleet.get(str(_state.active_uid))
		if is_instance_valid(active) and active.position.distance_squared_to(player.position) < 225.0:
			at = active.global_position
	player.focus_on(at)
	match _target.kind:
		"car": dialogs.vehicle(_target.key, true)
		"staged_car": dialogs.vehicle(_target.key, false)
		"travel": dialogs.destinations(sector_id)
		"tune": dialogs.tuning()
		"paint": dialogs.painting()
		"goals": dialogs.goals()
		"rival": dialogs.rival(_target.key)
		"event": dialogs.event_details(Catalog.event(_target.key))
		"practice": dialogs.practice()
		"offer": _open_offer(_target.key)
		"sell": dialogs.selling()


func _open_offer(key: String) -> void:
	for offer: Dictionary in _state.market_list():
		if offer.id == key:
			dialogs.offer_details(offer)
			return
	show_notice("Essa oferta mudou. Confira os carros no pátio.")


func _process(delta: float) -> void:
	if not is_instance_valid(sector):
		return
	sector.animate_people(delta, player.global_position)
	if dialogs.is_open():
		return
	if player.global_position.y < -6.0:
		player.place(sector.spawn, sector.spawn_yaw, 0.29)
		_update_target()
		return
	_sample_timer -= delta
	if _sample_timer <= 0.0:
		_sample_timer = 0.075
		_update_target()


func _update_target() -> void:
	if not is_instance_valid(sector):
		return
	var nearest := INF
	var candidate: Sector.Target
	var face := Vector3.FORWARD.rotated(Vector3.UP, player.yaw)
	var eye := player.global_position + Vector3.UP * 1.02
	for item in sector.targets:
		var offset := item.position - eye
		offset.y = 0.0
		var distance := offset.length()
		if distance > item.reach:
			continue
		var score := distance + (1.0 - face.dot(offset.normalized())) * 0.39
		if score >= nearest:
			continue
		var exclusions: Array[RID] = []
		if is_instance_valid(item.body):
			exclusions.append(item.body.get_rid())
		var ray := PhysicsRayQueryParameters3D.create(eye, item.position, Geometry.SOLID, exclusions)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		candidate = item
		nearest = score
	_set_target(candidate)


func _set_target(candidate: Sector.Target) -> void:
	_target = candidate
	if candidate == null:
		hud.set_context("", "")
		_marker.hide()
	else:
		hud.set_context(candidate.title, candidate.action)
		_marker.global_position = candidate.position + Vector3.UP * (1.37 if candidate.kind == "rival" else 0.82)
		_marker.visible = not dialogs.is_open()


func _on_modal(open: bool) -> void:
	hud.block_input(open)
	player.controls_enabled = not open
	player.reset_input()
	if not open:
		player.release_focus()
	_marker.visible = not open and _target != null


func _paint_preview(uid: String, color: String) -> void:
	if is_instance_valid(sector):
		sector.preview_paint(uid, color)


func _request_travel(destination: String) -> void:
	if _travel_pending or not is_instance_valid(sector):
		return
	_travel_pending = true
	release_controls()
	call_deferred("_travel", destination)


func _travel(destination: String) -> void:
	_travel_pending = false
	var response: Dictionary = _state.travel_to(destination)
	if not response.get("ok", false):
		show_notice(str(response.message))
		ui_cue.emit("error")
		return
	_load_sector(destination)
	_sync_hud()
	ui_cue.emit("select")


func _load_sector(destination: String, pose: Dictionary = {}) -> void:
	_set_target(null)
	_drop_sector()
	sector_id = destination
	sector = Sector.new()
	add_child(sector)
	sector.build(destination, _state)
	player.place(pose.get("position", sector.spawn), float(pose.get("yaw", sector.spawn_yaw)), float(pose.get("pitch", 0.29)))
	player.camera.make_current()
	hud.set_location(str(Catalog.SECTORS[destination].name))
	sector_changed.emit(destination)


func _drop_sector() -> void:
	if is_instance_valid(sector):
		remove_child(sector)
		sector.queue_free()
		sector = null


func _pose() -> Dictionary:
	return {"position": player.global_position, "yaw": player.yaw, "pitch": player.pitch}


func _queue_refresh() -> void:
	if _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_refresh")


func _refresh() -> void:
	_refresh_pending = false
	if not is_instance_valid(sector):
		return
	_sync_hud()
	if sector.signature != Sector.population_signature(sector_id, _state):
		_load_sector(sector_id, _pose())


func _sync_hud() -> void:
	hud.set_account(int(_state.money), int(_state.reputation))
	player.look_sensitivity = float(_state.settings.get("walk_sensitivity", 1.0))
