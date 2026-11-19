extends SceneTree

const State = preload("res://src/domain/game_state.gd")
const Catalog = preload("res://src/domain/catalog.gd")

var _failures := 0
var _path := "user://domain-smoke-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_msec()]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var profile := _open_profile()
	_expect(Catalog.VEHICLES.size() == 10 and Catalog.NPCS.size() == 12, "catálogo de carros e pilotos")
	_expect(profile.cars.size() == 1 and profile.money == 2500, "garagem inicial")
	_expect(profile.active_car().model == Catalog.STARTER, "modelo inicial")
	_expect(profile.event_status("estreia").ok and not profile.event_status("copa_cais").ok, "classificação e desbloqueio de evento")
	_expect(not profile.sell(profile.active_uid).ok, "proteção da garagem inicial")

	var spec := Catalog.effective(profile.active_car())
	_expect(profile.upgrade("engine").ok, "instalação de preparação")
	_expect(Catalog.effective(profile.active_car()).power > spec.power, "preparação altera potência")
	_expect(profile.paint("#406BB8").ok and profile.active_car().color == "#406BB8", "pintura")
	var before_race := profile.money
	_expect(not profile.finish_race({"race_id": "invalid"}).ok, "resultado sem inscrição")
	_expect(not profile.start_race("docas_noturnas", "lia", 1).ok, "validação de aposta baixa")

	var opening := profile.start_race("docas_noturnas", "lia", 500)
	_expect(opening.ok and profile.money == before_race - 500, "reserva da aposta fictícia")
	_expect(not profile.start_race("estreia").ok and not profile.upgrade("tires").ok, "bloqueio de alterações durante corrida")
	var ticket_id := _ticket_id(opening)
	profile.free()
	profile = _open_profile()
	var resumed := profile.resume_race()
	_expect(resumed.ok and _ticket_id(resumed) == ticket_id and profile.money == before_race - 500, "retomada do saldo reservado após recarga")
	var result := {"race_id": ticket_id, "event_id": "docas_noturnas", "completed": true, "won": true, "position": 1, "time_ms": 51000}
	_expect(profile.finish_race(result).get("payout", 0) == 1000 and profile.money == before_race + 500, "liquidação de aposta em dinheiro")
	_expect(profile.finish_race(result).get("payout", 0) == 1000 and profile.money == before_race + 500, "liquidação idempotente")
	_expect(profile.start_race("docas_noturnas", "lia", 500).ok and profile.cancel_race(true).ok and profile.money == before_race + 500, "reembolso para falha de inicialização")

	var pink_open := profile.start_race("docas_noturnas", "lia", 0, true)
	_expect(pink_open.ok, "aposta de chaves aceita")
	var lost := profile.finish_race({"race_id": _ticket_id(pink_open), "completed": true, "won": false, "position": 2})
	_expect(not lost.get("lost_car", {}).is_empty() and bool(lost.get("loaner")) and bool(profile.active_car().get("loaner")), "perda permanente da única propriedade e empréstimo de apoio")
	_expect(not profile.event_status("docas_noturnas").ok and profile.event_status("volta_limpa").ok, "prevenção de derrota sem recuperação")
	for attempt in 6:
		_win(profile, "estreia")
	var selected := _offer(profile, "dealer", "linha_rs")
	_expect(profile.purchase(str(selected.get("id", ""))).ok and profile.cars.size() == 1 and not profile.active_car().loaner, "substituição do empréstimo por carro próprio")

	var street := profile.start_race("docas_noturnas", "beto", 0, true)
	_expect(street.ok, "negociação de aposta entre carros equivalentes")
	var won := profile.finish_race({"race_id": _ticket_id(street), "completed": true, "won": true, "position": 1})
	_expect(won.get("won_car", {}).get("model") == "linha_rs" and profile.cars.size() == 2, "aquisição real do veículo rival")
	_expect(not profile.start_race("docas_noturnas", "beto", 0, true).ok, "rival perde o próprio carro apostado")

	var sales_quote := profile.sell_quote(str(profile.cars[0].uid))
	_expect(sales_quote.ok and not profile.sell_quote(str(profile.cars[0].uid), int(sales_quote.maximum) + 1).ok, "limite de negociação na venda")
	_expect(profile.sell(str(profile.cars[0].uid), int(sales_quote.maximum)).ok, "venda por proposta negociada")
	var private_offer := _offer(profile, "private", "brasa_16")
	var trade_quote := profile.market_quote(str(private_offer.get("id", "")), -1, profile.active_uid)
	_expect(trade_quote.ok and trade_quote.trade_value > 0, "avaliação de troca com particular")
	_expect(profile.purchase(str(private_offer.get("id", "")), -1, profile.active_uid).ok, "troca efetiva de veículos")
	_expect(not profile.market_quote(str(private_offer.get("id", ""))).ok, "anúncio particular consumido")

	for attempt in 6:
		_win(profile, "volta_limpa")
	var monte := _offer(profile, "dealer", "monte_gt")
	_expect(profile.purchase(str(monte.get("id", ""))).ok, "compra para classificação de campeonato")
	_expect(not profile.event_status("copa_serra").ok and not profile.event_status("compactos_do_clube").ok, "ordem de campeonato e categorias restritas")
	_win(profile, "copa_cais")
	_win(profile, "copa_serra")
	var final := _win(profile, "copa_apice")
	_expect(final.get("championship_bonus", 0) == 8500 and profile.stats.championships == 1, "classificação e prêmio de campeonato")
	_expect(_win(profile, "copa_apice").get("championship_bonus", -1) == 0, "prêmio de campeonato único")

	var original_save_path := profile.save_path
	profile.save_path = "user://domain-smoke-missing-%d/subdir/save.json" % OS.get_process_id()
	var original_setting: bool = profile.settings.assists
	_expect(not profile.set_setting("assists", not original_setting).ok and profile.settings.assists == original_setting, "rollback após falha de persistência")
	profile.save_path = original_save_path
	var balance_before_reload := profile.money
	profile.free()
	profile = _open_profile()
	_expect(profile.money == balance_before_reload and profile.active_car().model == "monte_gt", "persistência de saldo e garagem")
	_expect(profile.championship.get("copa_orla", {}).get("completed", false) and profile.stats.pink_wins == 1, "persistência de campeonatos e conquistas")
	profile.free()

	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("interrompido")
	file.close()
	profile = _open_profile()
	_expect(profile.active_car().model == "monte_gt" and profile.championship.get("copa_orla", {}).get("completed", false), "recuperação pela cópia de segurança")
	profile.free()
	for suffix in ["", ".bak", ".tmp"]:
		var entry: String = _path + suffix
		if FileAccess.file_exists(entry):
			DirAccess.remove_absolute(entry)
	if _failures == 0:
		print("Economia, garagem, campeonatos e persistência: testes concluídos.")
	quit(_failures)

func _open_profile() -> State:
	var profile := State.new()
	profile.save_path = _path
	root.add_child(profile)
	return profile

func _offer(profile: State, source: String, model: String) -> Dictionary:
	for offer: Dictionary in profile.market_list():
		if offer.source == source and (offer.model == model or model.is_empty()):
			return offer
	return {}

func _win(profile: State, event_id: String) -> Dictionary:
	var opening: Dictionary = profile.start_race(event_id)
	if not opening.ok:
		_expect(false, "%s disponível: %s" % [event_id, opening.message])
		return {}
	return profile.finish_race({
		"race_id": _ticket_id(opening), "event_id": event_id, "completed": true,
		"won": true, "position": 1, "time_ms": 50000,
	})

func _ticket_id(result: Dictionary) -> String:
	return str(result.get("race", {}).get("id", ""))

func _expect(condition: bool, check: String) -> void:
	if not condition:
		_failures += 1
		push_error("Falhou: " + check)
