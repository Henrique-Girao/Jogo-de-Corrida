extends SceneTree
## Run with godot --headless --script res://tests/race_simulation.gd.

const Race = preload("res://src/race/race_session.gd")
const Events = preload("res://src/race/race_events.gd")
const Catalog = preload("res://src/domain/catalog.gd")
const Domain = preload("res://src/domain/game_state.gd")
const STEP := 1.0 / 60.0

var _failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var domain := Domain.new()
	verify_route(domain, "estreia", "brasa_16")
	verify_route(domain, "seletiva", "brasa_16")
	var time_trial := verify_route(domain, "volta_limpa", "brasa_16")
	expect(time_trial.get("won", false), "O Brasa precisa conseguir bater o tempo de referência.")
	var drag := verify_route(domain, "reta_402", "brasa_16")
	expect(drag.get("won", false), "O Brasa precisa poder vencer com trocas na faixa verde.")
	var tuned_drag := verify_route(domain, "reta_402", "brasa_16", true, {"engine": 3, "turbo": 3})
	expect(float(tuned_drag.get("time", INF)) + 0.3 < float(drag.get("time", 0.0)), "A preparação precisa reduzir o tempo na arrancada.")
	var final := verify_route(domain, "copa_apice", "vetra_x")
	expect(int(final.get("best_lap_ms", 0)) < int(final.get("time_ms", 0)), "A final precisa registrar duas voltas.")
	var duel := verify_route(domain, "docas_noturnas", "brasa_16")
	expect(int(duel.get("field_size", 0)) == 2, "O duelo precisa ter um único rival.")
	var missed_shifts := verify_route(domain, "reta_402", "brasa_16", false)
	expect(not missed_shifts.get("won", true), "Uma arrancada sem trocas deve perder para o rival.")
	verify_pause_and_abort(domain)
	domain.free()
	if _failures == 0:
		print("Simulação de corrida concluída sem falhas.")
	quit(1 if _failures else 0)


func verify_route(domain: Node, event_id: String, model: String, shift := true, upgrades: Dictionary = {}) -> Dictionary:
	var race := create_race(domain, event_id, model, upgrades)
	var receipt: Array[Dictionary] = []
	race.race_finished.connect(func(result: Dictionary) -> void: receipt.append(result))
	# Drive using button-sized inputs, with the same gearing and brake limits as touch.
	race._player.driver.skill = 1.0
	race._player.driver.aggression = 0.88
	if race._mode != "drag":
		race._player.initial_lane = 0.0
	for frame in range(11000):
		apply_test_inputs(race, shift)
		race._physics_process(STEP)
		if not receipt.is_empty():
			break
	expect(receipt.size() == 1, event_id + " precisa emitir um resultado.")
	var result := receipt[0] if not receipt.is_empty() else {}
	expect(result.get("completed", false), event_id + " precisa chegar à faixa final.")
	expect(float(result.get("time", 0.0)) > 5.0, event_id + " precisa registrar o tempo de corrida.")
	expect(int(result.get("position", 0)) > 0, event_id + " precisa classificar o jogador.")
	if race._mode == "drag":
		expect(race._player.gear >= 4 if shift else race._player.gear == 1, "A arrancada precisa respeitar a troca manual.")
	print("%s: %s s, posição %s" % [event_id, result.get("time", 0.0), result.get("position", 0)])
	race.free()
	return result


func apply_test_inputs(race: Race, shift: bool) -> void:
	if race._mode == "drag":
		# Pulse the auxiliary input once as the rev band comes up.
		var shift_now := shift and race._player.shift_hint and not race._was_handbrake
		race.set_controls(0.0, 1.0, 0.0, shift_now)
		return
	var controls := race.choose_ai_controls(race._player)
	var steer := signf(controls.x) if absf(controls.x) > 0.21 else 0.0
	race.set_controls(steer, float(controls.y > 0.25), float(controls.z > 0.25))


func create_race(domain: Node, event_id: String, model: String, upgrades: Dictionary = {}) -> Race:
	var event := Events.get_event(event_id)
	var rivals: Array
	if event.underground:
		rivals = [domain._opponent("lia", {"model": "brasa_16"})]
	else:
		rivals = domain._official_opponents(event)
	var race := Race.new()
	race.configure(event, Catalog.effective({"model": model, "upgrades": upgrades}), rivals, {"quality": "low"})
	root.add_child(race)
	race.set_physics_process(false)
	return race


func verify_pause_and_abort(domain: Node) -> void:
	var race := create_race(domain, "docas_noturnas", "brasa_16")
	var receipt: Array[Dictionary] = []
	race.race_finished.connect(func(result: Dictionary) -> void: receipt.append(result))
	var start_countdown := race._countdown
	race.set_paused(true)
	race.set_controls(0.0, 1.0, 0.0)
	race._physics_process(STEP)
	expect(is_equal_approx(race._countdown, start_countdown), "A pausa precisa congelar a largada.")
	race.abort()
	race.abort()
	expect(receipt.size() == 1, "Abandonar em pausa precisa produzir um único resultado.")
	if not receipt.is_empty():
		var result := receipt[0]
		expect(not result.completed and not result.won, "Abandono deve contar como uma derrota.")
	race.free()


func expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
