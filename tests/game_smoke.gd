extends SceneTree

# Linux, starting in the project directory:
# XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . --script res://tests/game_smoke.gd --fixed-fps 60 -- --touch-controls
# Import the project first with Godot's editor or --headless --import.

const EVENT_ID := "reta_402"
const EVENT_TITLE := "Quarto de Milha"
const THROTTLE_FINGER := 0
const AUX_FINGER := 1

var _result: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data_home := OS.get_environment("XDG_DATA_HOME").simplify_path().trim_suffix("/")
	var user_path := ProjectSettings.globalize_path("user://").simplify_path()
	if not _expect(not data_home.is_empty() and user_path.begins_with(data_home + "/"),
			"Use um XDG_DATA_HOME temporário para isolar o salvamento."):
		return
	var state := root.get_node_or_null("GameState")
	if not _expect(state != null, "GameState não carregou."):
		return
	if not _expect(state.pending_race.is_empty() and state.last_race.is_empty() and int(state.stats.races) == 0,
			"Use um diretório de dados novo para o teste."):
		return
	var initial_money: int = state.money
	var initial_rep: int = state.reputation
	var initial_car: String = state.active_uid
	if not _expect(not initial_car.is_empty(), "Garagem inicial sem carro."):
		return

	var main := load("res://src/main.tscn") as PackedScene
	if not _expect(main != null, "A cena principal não carregou."):
		return
	var game := main.instantiate()
	root.add_child(game)
	await process_frame
	if not _expect(is_instance_valid(game.hub) and game.hub.visible, "Garagem invisível ao iniciar."):
		return
	if not _press(_find_button(game.hub, "Competições", true), "Acesso às competições"):
		return
	await process_frame
	var card_title := _find_label(game.hub, EVENT_TITLE)
	if not _expect(card_title != null, "Quarto de Milha ausente no calendário oficial."):
		return
	if not _press(_find_button(card_title.get_parent(), "Ver prova"), "Detalhes da arrancada"):
		return
	if not _press(_find_button(game.hub, "Inscrever e correr"), "Inscrição da arrancada"):
		return
	for frame in 3:
		await process_frame
	if not _expect(is_instance_valid(game.race) and is_instance_valid(game.hud) and not game.hub.visible,
			"A inscrição não abriu o HUD e a pista."):
		return

	Engine.max_fps = 0
	var race: Node = game.race
	var hud: Control = game.hud
	race.race_finished.connect(_capture_result)
	var race_id: String = str(game.active_ticket.get("id", ""))
	var entry: int = int(game.active_ticket.get("entry", 0))
	var save_path: String = state.save_path
	var reserved := _read_save(save_path)
	if not _expect(not race_id.is_empty() and str(reserved.get("pending_race", {}).get("id", "")) == race_id,
			"A inscrição não persistiu o bilhete de corrida."):
		return

	_touch(hud, "throttle", THROTTLE_FINGER, true)
	if not await _wait_for(func() -> bool: return float(hud.telemetry.get("speed_kmh", 0.0)) >= 30.0, 640):
		_expect(false, "A aceleração por toque não atingiu 30 km/h.")
		return
	var moving_time := int(hud.telemetry.get("time_ms", 0))
	if not _press(hud.pause_button, "Pausa"):
		return
	for frame in 24:
		await physics_frame
	if not _expect(hud.paused and hud.touches.is_empty() and int(hud.telemetry.get("time_ms", 0)) <= moving_time + 55,
			"A pausa avançou a corrida ou manteve um toque ativo."):
		return
	_touch(hud, "throttle", THROTTLE_FINGER, false)
	if not _press(_find_button(hud, "Continuar"), "Retomada da corrida"):
		return
	_touch(hud, "throttle", THROTTLE_FINGER, true)
	var resumed := func() -> bool:
		var clock_advanced := int(hud.telemetry.get("time_ms", 0)) > moving_time + 150
		return clock_advanced and float(hud.telemetry.get("throttle", 0.0)) > 0.9
	if not await _wait_for(resumed, 90):
		_expect(false, "A retomada não aceitou novamente o acelerador por toque.")
		return

	var requested_gear := 0
	var max_gear := 0
	var aux_pressed := false
	for frame in 2700:
		await physics_frame
		if not _result.is_empty():
			break
		var gear := int(hud.telemetry.get("gear", 0))
		max_gear = maxi(max_gear, gear)
		if aux_pressed:
			_touch(hud, "aux", AUX_FINGER, false)
			aux_pressed = false
		elif gear != requested_gear and bool(hud.telemetry.get("shift_hint", false)):
			_touch(hud, "aux", AUX_FINGER, true)
			requested_gear = gear
			aux_pressed = true
	_touch(hud, "throttle", THROTTLE_FINGER, false)
	if not _expect(max_gear >= 2, "O toque em marcha não engatou a segunda."):
		return
	if not _expect(bool(_result.get("completed", false)) and _result.get("event_id") == EVENT_ID
			and int(_result.get("time_ms", 0)) > 0,
			"A arrancada não produziu uma chegada válida em 45 s."):
		return
	if not _expect(hud.finished and game.race_settled and state.pending_race.is_empty(),
			"O resultado não foi liquidado pela cena principal."):
		return
	var receipt: Dictionary = state.last_race
	var payout: int = int(receipt.get("payout", 0))
	var rep_gain: int = int(receipt.get("rep", 0))
	if not _expect(bool(receipt.get("ok", false)) and receipt.get("race_id") == race_id and payout > 0
			and state.money == initial_money - entry + payout and state.reputation == initial_rep + rep_gain
			and state.active_uid == initial_car and int(state.stats.races) == 1,
			"Saldo, reputação, carro ou resultado divergiram após a prova."):
		return

	if not _press(_find_button(hud, "Voltar aos setores"), "Voltar aos setores"):
		return
	await process_frame
	var saved := _read_save(save_path)
	var saved_receipt: Dictionary = saved.get("last_race", {})
	var saved_records: Dictionary = saved.get("records", {})
	var saved_record: Dictionary = saved_records.get(EVENT_ID, {})
	if not _expect(not is_instance_valid(game.race) and game.hub.visible,
			"O resultado não retornou ao calendário."):
		return
	if not _expect(saved.get("pending_race", {"pending": true}).is_empty()
			and saved_receipt.get("race_id") == race_id and int(saved_receipt.get("payout", 0)) == payout
			and int(saved.get("money", -1)) == state.money and int(saved_record.get("attempts", 0)) == 1
			and int(saved_record.get("best_ms", 0)) == int(_result.time_ms),
			"O arquivo salvo diverge da liquidação ou do histórico da corrida."):
		return

	print("GAME SMOKE OK | %s | %dº | %.3f s | marcha %d | prêmio Cr %d" % [
		EVENT_ID, int(_result.position), int(_result.time_ms) / 1000.0, max_gear, payout])
	quit(0)


func _touch(hud: Control, zone: String, finger: int, pressed: bool) -> void:
	var hit_area: Rect2 = hud.touch_zones[zone]
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = hud.get_global_transform_with_canvas() * hit_area.get_center()
	event.pressed = pressed
	root.push_input(event, true)


func _wait_for(condition: Callable, frames: int) -> bool:
	for frame in frames:
		if condition.call():
			return true
		await physics_frame
	return false


func _capture_result(result: Dictionary) -> void:
	_result = result.duplicate(true)


func _read_save(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _find_button(node: Node, label: String, tooltip := false) -> Button:
	if node is Button:
		var text: String = node.tooltip_text if tooltip else node.text
		if text.strip_edges().begins_with(label):
			return node
	for child in node.get_children():
		var match_button := _find_button(child, label, tooltip)
		if match_button != null:
			return match_button
	return null


func _find_label(node: Node, text: String) -> Label:
	if node is Label and node.text == text:
		return node
	for child in node.get_children():
		var match_label := _find_label(child, text)
		if match_label != null:
			return match_label
	return null


func _press(button: Button, context: String) -> bool:
	if not _expect(is_instance_valid(button) and not button.disabled, "Botão indisponível. " + context):
		return false
	button.pressed.emit()
	return true


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GAME SMOKE FAIL | " + message)
		quit(1)
	return condition
