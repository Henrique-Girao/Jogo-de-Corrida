extends Node

signal changed
signal saved

const Catalog = preload("res://src/domain/catalog.gd")
const Market = preload("res://src/domain/market.gd")
const SaveStore = preload("res://src/domain/save_store.gd")
const SAVE_PATH := "user://asfalto_de_troca.json"
const INITIAL_MONEY := 2500
const PURCHASE_LIMIT := 99
const PAINT_PRICE := 150
const DEFAULT_SETTINGS := {
	"sensitivity": 1.0, "walk_sensitivity": 1.0, "assists": true, "quality": "auto", "fps": 60, "sound": true,
	"master_volume": 1.0, "music_volume": 0.68, "effects_volume": 0.82,
}
const DEFAULT_STATS := {
	"races": 0, "wins": 0, "official_wins": 0, "street_wins": 0, "pink_wins": 0,
	"cars_acquired": 0, "tunes": 0, "trades": 0, "sold": 0, "profit": 0,
	"earned": 0, "races_abandoned": 0, "championships": 0,
}
const STREET_ROSTERS := {
	"docas_noturnas": ["lia", "beto", "nia", "cida"],
	"descida_secreta": ["gael", "iris", "raul", "maya", "sol"],
	"sinal_verde": ["lia", "beto", "nia", "toni", "iris", "maya", "lara", "dante"],
}

var save_path := SAVE_PATH
var money := INITIAL_MONEY
var reputation := 0
var cars: Array[Dictionary] = []
var active_uid := ""
var last_sector := "garage"
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var stats: Dictionary = DEFAULT_STATS.duplicate()
var pending_race: Dictionary = {}
var last_race: Dictionary = {}
var records: Dictionary = {}
var championship: Dictionary = {}

var _sequence := 0
var _market_epoch := 0
var _rival_cars: Dictionary = {}

func _ready() -> void:
	var payload := SaveStore.load_game(save_path)
	if payload.is_empty():
		_reset()
		save_game()
		return
	_apply(payload)
	_ensure_vehicle()

func new_game() -> Dictionary:
	var previous := _snapshot()
	_reset()
	return _commit(previous, _ok("Uma nova trajetória começa na garagem."))

func save_game() -> bool:
	if SaveStore.save_game(save_path, _snapshot()) != OK:
		return false
	saved.emit()
	return true

func active_car() -> Dictionary:
	return owned_car(active_uid)

func owned_car(uid: String) -> Dictionary:
	return _find_car(uid).duplicate(true)

func travel_to(sector: String) -> Dictionary:
	if not Catalog.SECTORS.has(sector):
		return _fail("Este setor de Baía do Sal não existe.")
	if not pending_race.is_empty():
		return _fail("Encerre a corrida em andamento antes de viajar.")
	if last_sector == sector:
		return _ok("Você já está neste setor.")
	var previous := _snapshot()
	last_sector = sector
	return _commit(previous, _ok("Chegada a %s." % str(Catalog.SECTORS[sector].name)))

func rival_garage() -> Dictionary:
	var lineup: Dictionary = {}
	for id: String in Catalog.NPCS:
		lineup[id] = Catalog.effective(_rival_car(id))
	return lineup

func select_car(uid: String) -> Dictionary:
	if not pending_race.is_empty():
		return _fail("Encerre a corrida em andamento antes de trocar de carro.")
	if _find_car(uid).is_empty():
		return _fail("Este carro está fora da sua garagem.")
	var previous := _snapshot()
	active_uid = uid
	return _commit(previous, _ok("Carro selecionado."))

func net_worth() -> int:
	var total := money
	for car in cars:
		total += Catalog.car_value(car)
	return total

func market_list() -> Array[Dictionary]:
	return Market.listing(reputation, _market_epoch)

func market_quote(offer_id: String, offer_price: int = -1, trade_uid: String = "") -> Dictionary:
	if not pending_race.is_empty():
		return _fail("O comércio reabre ao encerrar sua corrida.")
	var offer := _find_offer(offer_id)
	if offer.is_empty():
		return _fail("A oferta expirou. Consulte os anúncios atuais.")
	var trade := _find_car(trade_uid)
	if not trade_uid.is_empty() and (trade.is_empty() or bool(trade.get("loaner", false))):
		return _fail("Escolha um veículo próprio para a troca.")
	if cars.size() >= PURCHASE_LIMIT and trade.is_empty():
		return _fail("Sua garagem está cheia.")
	return Market.buy_quote(offer, offer_price, trade, money)

func purchase(offer_id: String, offer_price: int = -1, trade_uid: String = "") -> Dictionary:
	var quote := market_quote(offer_id, offer_price, trade_uid)
	if not quote.ok:
		return quote
	var previous := _snapshot()
	var trade := _find_car(trade_uid)
	if not trade.is_empty():
		_record_sale(trade, int(quote.trade_value))
		_remove_car(trade_uid)
		stats.trades += 1
		_gain_reputation_for_deal()
	money -= int(quote.net)
	var offer: Dictionary = quote.offer
	var new_car := _add_car(str(offer.model), str(offer.color), {}, int(quote.price))
	active_uid = str(new_car.uid)
	stats.cars_acquired += 1
	_gain_reputation_for_deal()
	_market_epoch += 1
	var action := "Troca concluída" if not trade_uid.is_empty() else "Comprado"
	return _commit(previous, _ok("%s · %s" % [action, Catalog.vehicle(str(offer.model)).name], {
		"car": new_car.duplicate(true), "net": int(quote.net), "trade_value": int(quote.trade_value),
	}))

func sell_quote(uid: String, offer_price: int = -1) -> Dictionary:
	if not pending_race.is_empty():
		return _fail("O comércio reabre ao encerrar sua corrida.")
	var car := _find_car(uid)
	if car.is_empty() or bool(car.get("loaner", false)):
		return _fail("Somente carros próprios podem ser vendidos.")
	if cars.size() < 2:
		return _fail("Mantenha um carro na garagem ou use-o como parte de uma troca.")
	return Market.sell_quote(car, offer_price, _market_epoch)

func sell(uid: String, offer_price: int = -1) -> Dictionary:
	var quote := sell_quote(uid, offer_price)
	if not quote.ok:
		return quote
	var car := _find_car(uid)
	var previous := _snapshot()
	money += int(quote.price)
	_record_sale(car, int(quote.price))
	_remove_car(uid)
	_ensure_vehicle()
	_market_epoch += 1
	_gain_reputation_for_deal()
	return _commit(previous, _ok("Vendido para %s por Cr %d." % [quote.buyer, quote.price], {
		"price": int(quote.price), "buyer": str(quote.buyer),
	}))

func upgrade_quote(key: String, uid: String = "") -> Dictionary:
	if not Catalog.UPGRADES.has(key):
		return _fail("Este componente não existe.")
	var car := _find_car(active_uid if uid.is_empty() else uid)
	if car.is_empty() or bool(car.get("loaner", false)):
		return _fail("A oficina só prepara carros próprios.")
	if not pending_race.is_empty():
		return _fail("A oficina reabre ao encerrar sua corrida.")
	var current := int(car.upgrades.get(key, 0))
	var price := Catalog.upgrade_cost(str(car.model), key, current + 1)
	if current >= Catalog.MAX_UPGRADE_LEVEL:
		return {"ok": false, "message": "Componente no nível máximo.", "level": current, "cost": 0}
	var update := car.duplicate(true)
	update.upgrades[key] = current + 1
	var can_afford := money >= price
	var message := ("Instalar por Cr %d." if can_afford else "Saldo insuficiente. Preço Cr %d.") % price
	return {"ok": can_afford, "message": message, "level": current, "cost": price, "spec": Catalog.effective(update)}

func upgrade(key: String, uid: String = "") -> Dictionary:
	var quote := upgrade_quote(key, uid)
	if not quote.ok:
		return quote
	var previous := _snapshot()
	var car := _find_car(active_uid if uid.is_empty() else uid)
	car.upgrades[key] = int(quote.level) + 1
	car.cost_basis = int(car.get("cost_basis", 0)) + int(quote.cost)
	money -= int(quote.cost)
	stats.tunes += 1
	return _commit(previous, _ok("%s instalado · nível %d" % [Catalog.UPGRADES[key].name, car.upgrades[key]], {
		"level": int(car.upgrades[key]), "cost": int(quote.cost),
	}))

func paint(color: String, uid: String = "") -> Dictionary:
	if not pending_race.is_empty():
		return _fail("A oficina reabre ao encerrar sua corrida.")
	if not Color.html_is_valid(color):
		return _fail("Selecione uma cor válida.")
	var car := _find_car(active_uid if uid.is_empty() else uid)
	if car.is_empty() or bool(car.get("loaner", false)):
		return _fail("A pintura só está disponível em carros próprios.")
	var hex := "#" + Color.html(color).to_html(false).to_upper()
	if hex == str(car.color).to_upper():
		return _ok("A cor já está aplicada.")
	if money < PAINT_PRICE:
		return _fail("A pintura custa Cr %d." % PAINT_PRICE)
	var previous := _snapshot()
	money -= PAINT_PRICE
	car.color = hex
	return _commit(previous, _ok("Pintura aplicada.", {"color": hex, "cost": PAINT_PRICE}))

func set_setting(key: String, value: Variant) -> Dictionary:
	if not DEFAULT_SETTINGS.has(key):
		return _fail("Configuração desconhecida.")
	var previous := _snapshot()
	match key:
		"sensitivity", "walk_sensitivity":
			settings[key] = clampf(float(value), 0.55, 1.55)
		"quality":
			var quality := str(value)
			settings[key] = quality if quality in ["auto", "low", "high"] else "auto"
		"fps":
			settings[key] = 30 if int(value) <= 30 else 60
		"master_volume", "music_volume", "effects_volume":
			settings[key] = clampf(float(value), 0.0, 1.0)
		_:
			settings[key] = bool(value)
	return _commit(previous, _ok("Configuração salva."))

func event_status(event_id: String) -> Dictionary:
	var event := Catalog.event(event_id)
	if event.is_empty():
		return _fail("Evento desconhecido.")
	var car := _find_car(active_uid)
	if car.is_empty():
		return _fail("Escolha um carro na garagem.")
	var required_rep: int = event.get("reputation", 0)
	if reputation < required_rep:
		return _fail("Requer reputação %d." % required_rep)

	var series := str(event.get("series", ""))
	var round_number := int(event.get("round", 0))
	if not series.is_empty() and round_number > 1:
		var standings: Dictionary = championship.get(series, {})
		var positions: Dictionary = standings.get("best_positions", {})
		if not positions.has(str(round_number - 1)):
			return _fail("Complete a etapa anterior da Copa da Orla.")

	var spec := Catalog.effective(car)
	var minimum := int(event.get("min_rating", 0))
	var maximum := int(event.get("max_rating", 9999))
	var rating: int = spec.rating
	if rating < minimum:
		return _fail("Seu carro precisa atingir índice %d." % minimum)
	if rating > maximum:
		return _fail("O limite de desempenho desta prova é %d." % maximum)
	var categories: Array = event.get("categories", [])
	if not categories.is_empty() and not categories.has(spec.category_id):
		return _fail("A categoria do seu carro não participa desta prova.")
	if bool(car.get("loaner", false)) and bool(event.get("underground", false)):
		return _fail("O carro de apoio está disponível para competições oficiais.")
	var entry := int(event.get("entry", 0))
	if money < entry:
		return _fail("A inscrição custa Cr %d." % entry)
	return _ok("Evento disponível.")

func street_rivals(event_id: String) -> Array[Dictionary]:
	var rivals: Array[Dictionary] = []
	var event := Catalog.event(event_id)
	if not bool(event.get("underground", false)):
		return rivals
	var car := _find_car(active_uid)
	var player_value := Catalog.car_value(car)
	for id: String in STREET_ROSTERS.get(event_id, []):
		var person := Catalog.npc(id)
		var rival_car := _rival_car(id)
		var rival_spec := Catalog.effective(rival_car)
		if reputation + 2 < int(rival_spec.rep):
			continue
		var minimum: int = event.get("min_wager", 0)
		var cap := _round_price(float(person.budget) * (0.08 + float(person.risk) * 0.24))
		var maximum := mini(int(event.get("max_wager", 0)), maxi(minimum, cap))
		var pink_check := _pink_status(event, person, rival_car, player_value)
		person["car"] = rival_car.model
		person["car_name"] = rival_spec.name
		person["car_value"] = Catalog.car_value(rival_car)
		person["min_wager"] = minimum
		person["max_wager"] = maximum
		person["pink"] = pink_check.ok
		person["pink_reason"] = pink_check.message
		person["suggestion"] = clampi(_round_price(float(minimum + maximum) * 0.5), minimum, maximum)
		person["rating"] = int(rival_spec.rating)
		rivals.append(person)
	return rivals

func start_race(event_id: String, npc_id: String = "", wager: int = 0, pink: bool = false) -> Dictionary:
	if not pending_race.is_empty():
		return _fail("Já existe uma corrida em andamento.")
	var status := event_status(event_id)
	if not status.ok:
		return status
	var event := Catalog.event(event_id)
	var car := _find_car(active_uid)
	var street: bool = event.get("underground", false)
	var entry: int = event.get("entry", 0)
	var opponent: Dictionary = {}
	var prize_car: Dictionary = {}
	var opponents: Array[Dictionary] = []
	if street:
		opponent = _find_rival(event_id, npc_id)
		if opponent.is_empty():
			return _fail("Este piloto não está aceitando desafios aqui.")
		if pink:
			if not bool(opponent.pink):
				return _fail(str(opponent.pink_reason))
			if wager != 0:
				return _fail("Aposte as chaves ou dinheiro, separadamente.")
			prize_car = _rival_car(npc_id)
			wager = 0
		elif wager < int(opponent.min_wager) or wager > int(opponent.max_wager):
			return _fail("Faça uma aposta entre Cr %d e Cr %d." % [opponent.min_wager, opponent.max_wager])
		opponents.append(_opponent(npc_id, _rival_car(npc_id)))
	else:
		if pink or wager != 0:
			return _fail("Competições oficiais não aceitam apostas.")
		opponents = _official_opponents(event)
	if money < entry + wager:
		return _fail("Saldo insuficiente para cobrir esta corrida.")

	var previous := _snapshot()
	money -= entry + wager
	pending_race = {
		"id": _next_id("r"), "event_id": event_id, "event": event, "car": Catalog.effective(car),
		"car_uid": str(car.uid), "npc": opponent, "opponents": opponents, "prize_car": prize_car,
		"settings": settings.duplicate(), "wager": wager, "pink": pink, "entry": entry,
	}
	return _commit(previous, _ok("Inscrição confirmada.", {"race": pending_race.duplicate(true)}))

func resume_race() -> Dictionary:
	if pending_race.is_empty():
		return _fail("Não há corrida pendente.")
	var ticket := pending_race.duplicate(true)
	ticket.settings = settings.duplicate()
	return _ok("Corrida retomada a partir da largada.", {"race": ticket})

func cancel_race(refund: bool = false) -> Dictionary:
	if pending_race.is_empty():
		return _fail("Não há corrida pendente.")
	if not refund:
		return finish_race({"race_id": pending_race.id, "event_id": pending_race.event_id, "completed": false})
	var previous := _snapshot()
	var returned := int(pending_race.entry) + int(pending_race.wager)
	money += returned
	pending_race = {}
	return _commit(previous, _ok("Inscrição desfeita e saldo devolvido.", {"payout": returned}))

func finish_race(result: Dictionary) -> Dictionary:
	var race_id := str(result.get("race_id", ""))
	if not race_id.is_empty() and race_id == str(last_race.get("race_id", "")):
		return last_race.duplicate(true)
	if pending_race.is_empty():
		return _fail("Não há corrida pendente.")
	var ticket := pending_race
	if (not race_id.is_empty() and race_id != str(ticket.id)) or str(result.get("event_id", ticket.event_id)) != str(ticket.event_id):
		return _fail("O resultado pertence a outra corrida.")

	var previous := _snapshot()
	var event: Dictionary = ticket.event
	var street: bool = event.get("underground", false)
	var completed := bool(result.get("completed", true))
	var position := maxi(int(result.get("position", 0)), 0)
	var won := completed and bool(result.get("won", position == 1))
	var payout := 0
	var reputation_gain := 0
	var bonus := 0
	var won_car: Dictionary = {}
	var lost_car: Dictionary = {}
	var vehicle_recovery := false
	var message := "Corrida encerrada."
	if completed:
		stats.races += 1
		_market_epoch += 1
		if won:
			stats.wins += 1
		_update_record(str(ticket.event_id), result, won)
	else:
		message = "Corrida abandonada."
		stats.races_abandoned += 1

	if not street and completed:
		var reward: int = event.get("reward", 0)
		payout = roundi(float(reward) * _official_share(position, won, str(event.mode)))
		reputation_gain = 2 if won else (1 if position > 0 and position <= 3 else 0)
		if won:
			stats.official_wins += 1
		bonus = _record_championship(event, position)
		if bonus > 0:
			message = "Copa da Orla conquistada."
			reputation_gain += 3
		elif won:
			message = "Vitória em %s." % event.name
	elif street:
		if won:
			stats.street_wins += 1
			reputation_gain = 2
			message = "Desafio vencido."
		if bool(ticket.pink):
			if won:
				var prize: Dictionary = ticket.prize_car
				won_car = _add_car(str(prize.model), str(prize.color), prize.upgrades, 0)
				active_uid = str(won_car.uid)
				stats.cars_acquired += 1
				stats.pink_wins += 1
				_rival_cars[str(ticket.npc.id)] = _loaner_record()
				message = "Você ganhou o %s no Pink Slip." % Catalog.vehicle(str(prize.model)).name
			else:
				var forfeit := _find_car(str(ticket.car_uid))
				if not forfeit.is_empty():
					lost_car = forfeit.duplicate(true)
					_rival_cars[str(ticket.npc.id)] = forfeit.duplicate(true)
					_remove_car(str(forfeit.uid))
					vehicle_recovery = _ensure_vehicle()
					message = "%s ficou com seu %s." % [ticket.npc.name, Catalog.vehicle(str(forfeit.model)).name]
					if vehicle_recovery:
						message += " A Revenda do Cais emprestou um Brasa para você voltar às provas oficiais."
		elif won:
			payout = int(ticket.wager) * 2
		elif int(ticket.wager) > 0:
			message += " A aposta de Cr %d foi perdida." % int(ticket.wager)

	payout += bonus
	money += payout
	stats.earned += maxi(0, payout - int(ticket.wager) - int(ticket.entry))
	reputation += reputation_gain
	var receipt := _ok(message, {
		"race_id": str(ticket.id), "event_id": str(ticket.event_id), "payout": payout,
		"net": payout - int(ticket.wager) - int(ticket.entry), "rep": reputation_gain,
		"won_car": won_car.duplicate(true), "lost_car": lost_car,
		"loaner": vehicle_recovery, "championship_bonus": bonus, "won": won,
	})
	last_race = receipt.duplicate(true)
	pending_race = {}
	return _commit(previous, receipt)

func goals() -> Array[Dictionary]:
	var model_ids: Dictionary = {}
	var japanese := 0
	var max_tuning := 0
	for car in cars:
		if bool(car.get("loaner", false)):
			continue
		var spec := Catalog.vehicle(str(car.model))
		if spec.category_id == "jdm":
			japanese += 1
		var tuning_points := 0
		for level in car.upgrades.values():
			tuning_points += int(level)
		max_tuning = maxi(max_tuning, tuning_points)
		model_ids[str(car.model)] = true
	return [
		_goal("first_win", "Primeira bandeirada", "Vença uma prova oficial.", int(stats.official_wins), 1),
		_goal("pink_slip", "Mudança de dono", "Conquiste as chaves de um rival.", int(stats.pink_wins), 1),
		_goal("collections", "Garagem de respeito", "Tenha cinco modelos próprios diferentes.", model_ids.size(), 5),
		_goal("profit", "Bom de negócio", "Ganhe Cr 1.000 de lucro na revenda ou troca.", int(stats.profit), 1000),
		_goal("japanese", "Garagem do Pacífico", "Colecione dois esportivos japoneses.", japanese, 2),
		_goal("workshop", "Acerto completo", "Instale todos os níveis de preparação em um mesmo carro.", max_tuning, Catalog.UPGRADES.size() * Catalog.MAX_UPGRADE_LEVEL),
		_goal("cup", "Campeão da Orla", "Some 27 pontos ou mais nas três etapas da Copa da Orla.", int(stats.championships), 1),
		_goal("worth", "Patrimônio de pista", "Some Cr 100.000 entre saldo e carros.", net_worth(), 100000),
	]

func _pink_status(event: Dictionary, person: Dictionary, rival_car: Dictionary, player_value: int) -> Dictionary:
	if not bool(event.get("pink", false)):
		return _fail("Este evento não tem Pink Slip.")
	if bool(rival_car.get("loaner", false)):
		return _fail("%s está usando um carro de apoio e aceita somente dinheiro." % person.name)
	if player_value <= 0:
		return _fail("Você precisa de um carro próprio para apostar as chaves.")
	var threshold := 0.90 - float(person.risk) * 0.39
	var minimum_value := _round_price(float(Catalog.car_value(rival_car)) * threshold)
	if player_value < minimum_value:
		return _fail("%s só aceita chaves de um carro que valha Cr %d ou mais." % [person.name, minimum_value])
	if cars.size() >= PURCHASE_LIMIT:
		return _fail("Libere espaço na garagem antes de apostar as chaves.")
	return _ok("Aposta de veículo aceita.")

func _find_rival(event_id: String, npc_id: String) -> Dictionary:
	for rival in street_rivals(event_id):
		if str(rival.id) == npc_id:
			return rival
	return {}

func _rival_car(id: String) -> Dictionary:
	if _rival_cars.has(id):
		var recorded: Dictionary = _rival_cars[id]
		return recorded.duplicate(true)
	var person := Catalog.npc(id)
	var spec := Catalog.vehicle(str(person.car))
	return {"model": str(spec.id), "color": str(spec.color), "upgrades": {}}

func _official_opponents(event: Dictionary) -> Array[Dictionary]:
	var lineup: Dictionary = {
		"estreia": ["lia", "beto", "nia"],
		"seletiva": ["lia", "nia", "cida"],
		"reta_402": ["lia"],
		"copa_cais": ["beto", "nia", "cida", "gael"],
		"copa_serra": ["beto", "cida", "gael", "iris"],
		"copa_apice": ["cida", "gael", "iris", "maya", "sol"],
		"compactos_do_clube": ["lia", "beto", "nia", "gael"],
	}
	var opponents: Array[Dictionary] = []
	var roster: Array = lineup.get(str(event.id), Catalog.NPCS.keys())
	for index in mini(int(event.opponents), roster.size()):
		var id := str(roster[index])
		var person := Catalog.npc(id)
		var spec := Catalog.vehicle(str(person.car))
		opponents.append(_opponent(id, {"model": spec.id, "color": spec.color}))
	return opponents

func _opponent(id: String, car: Dictionary) -> Dictionary:
	var person := Catalog.npc(id)
	return {
		"id": id, "name": str(person.name), "skill": float(person.skill),
		"aggression": float(person.aggression), "spec": Catalog.effective(car),
	}

func _record_championship(event: Dictionary, position: int) -> int:
	var series := str(event.get("series", ""))
	if series.is_empty() or position == 0:
		return 0
	var current: Dictionary = championship.get(series, {"best_positions": {}, "points": 0, "completed": false})
	var places: Dictionary = current.best_positions
	var stage := str(int(event.get("round", 0)))
	places[stage] = mini(position, int(places.get(stage, position)))
	var points := 0
	for place in places.values():
		points += [12, 8, 5, 3, 2, 1][clampi(int(place) - 1, 0, 5)]
	current.points = points
	championship[series] = current
	if places.size() < int(event.get("rounds", 0)) or bool(current.completed) or points < 27:
		return 0
	current.completed = true
	stats.championships += 1
	return int(event.get("series_reward", 0))

func _update_record(event_id: String, result: Dictionary, won: bool) -> void:
	var record: Dictionary = records.get(event_id, {"attempts": 0, "wins": 0, "best_ms": 0, "best_position": 0})
	record.attempts += 1
	if won:
		record.wins += 1
	var milliseconds := int(result.get("time_ms", roundi(float(result.get("time", 0.0)) * 1000.0)))
	if milliseconds > 0 and (int(record.best_ms) <= 0 or milliseconds < int(record.best_ms)):
		record.best_ms = milliseconds
	var position := int(result.get("position", 0))
	if position > 0 and (int(record.best_position) <= 0 or position < int(record.best_position)):
		record.best_position = position
	records[event_id] = record

func _official_share(position: int, won: bool, mode: String) -> float:
	if won:
		return 1.0
	if mode == "time_trial":
		return 0.28
	match position:
		2:
			return 0.62
		3:
			return 0.41
		_:
			return 0.25

func _goal(id: String, title: String, description: String, progress: int, target: int) -> Dictionary:
	return {"id": id, "title": title, "description": description, "progress": mini(progress, target), "target": target, "done": progress >= target}

func _find_offer(id: String) -> Dictionary:
	for offer in market_list():
		if str(offer.id) == id:
			return offer
	return {}

func _find_car(uid: String) -> Dictionary:
	for car in cars:
		if str(car.uid) == uid:
			return car
	return {}

func _add_car(model: String, color: String, upgrades: Dictionary, cost_basis: int) -> Dictionary:
	var loaner := _find_loaner()
	if not loaner.is_empty():
		_remove_car(str(loaner.uid))
	var car := {
		"uid": _next_id("v"), "model": model, "color": color, "upgrades": upgrades.duplicate(true),
		"cost_basis": cost_basis, "loaner": false,
	}
	cars.append(car)
	return car

func _remove_car(uid: String) -> void:
	for index in cars.size():
		if str(cars[index].uid) == uid:
			cars.remove_at(index)
			return

func _ensure_vehicle() -> bool:
	if cars.is_empty():
		var car := _loaner_record()
		car.uid = _next_id("v")
		cars.append(car)
		active_uid = str(car.uid)
		return true
	if _find_car(active_uid).is_empty():
		active_uid = str(cars[0].uid)
	return false

func _loaner_record() -> Dictionary:
	return {
		"model": Catalog.STARTER, "color": "#F6F2E9", "upgrades": {}, "cost_basis": 0, "loaner": true,
	}

func _find_loaner() -> Dictionary:
	for car in cars:
		if bool(car.get("loaner", false)):
			return car
	return {}

func _record_sale(car: Dictionary, sale_price: int) -> void:
	stats.sold += 1
	stats.profit += maxi(0, sale_price - int(car.get("cost_basis", 0)))

func _gain_reputation_for_deal() -> void:
	var total_deals := int(stats.sold) + int(stats.cars_acquired)
	if total_deals > 0 and total_deals % 3 == 0:
		reputation += 1

func _reset() -> void:
	money = INITIAL_MONEY
	reputation = 0
	cars.clear()
	active_uid = ""
	last_sector = "garage"
	settings = DEFAULT_SETTINGS.duplicate()
	settings.fps = 30 if OS.has_feature("mobile") else 60
	stats = DEFAULT_STATS.duplicate()
	pending_race = {}
	last_race = {}
	records = {}
	championship = {}
	_market_epoch = 0
	_sequence = 0
	_rival_cars = {}
	var spec := Catalog.vehicle(Catalog.STARTER)
	var starter := _add_car(Catalog.STARTER, str(spec.color), {}, int(spec.value))
	active_uid = str(starter.uid)

func _snapshot() -> Dictionary:
	return {
		"version": 1, "money": money, "reputation": reputation, "cars": cars.duplicate(true),
		"active_uid": active_uid, "last_sector": last_sector, "settings": settings.duplicate(), "stats": stats.duplicate(),
		"pending_race": pending_race.duplicate(true), "last_race": last_race.duplicate(true), "records": records.duplicate(true),
		"championship": championship.duplicate(true), "market_epoch": _market_epoch,
		"sequence": _sequence, "rival_cars": _rival_cars.duplicate(true),
	}

func _apply(payload: Dictionary) -> void:
	money = maxi(0, int(payload.get("money", INITIAL_MONEY)))
	reputation = maxi(0, int(payload.get("reputation", 0)))
	active_uid = str(payload.get("active_uid", ""))
	var sector := str(payload.get("last_sector", "garage"))
	last_sector = sector if Catalog.SECTORS.has(sector) else "garage"
	settings = DEFAULT_SETTINGS.duplicate()
	settings.fps = 30 if OS.has_feature("mobile") else 60
	var stored_settings := _dictionary(payload.get("settings", {}))
	for key in DEFAULT_SETTINGS:
		settings[key] = stored_settings.get(key, settings[key])
	stats = DEFAULT_STATS.duplicate()
	var stored_stats := _dictionary(payload.get("stats", {}))
	for key in DEFAULT_STATS:
		stats[key] = int(stored_stats.get(key, stats[key]))
	cars.clear()
	for item in payload.get("cars", []):
		var car := _dictionary(item)
		var model := str(car.get("model", ""))
		var uid := str(car.get("uid", ""))
		if not Catalog.VEHICLES.has(model) or uid.is_empty() or not _find_car(uid).is_empty():
			continue
		var spec := Catalog.vehicle(model)
		var upgrades := _dictionary(car.get("upgrades", {}))
		var color := str(car.get("color", spec.color))
		cars.append({
			"uid": uid, "model": model, "color": color if Color.html_is_valid(color) else str(spec.color),
			"upgrades": upgrades.duplicate(), "cost_basis": int(car.get("cost_basis", spec.value)),
			"loaner": bool(car.get("loaner", false)),
		})
	_market_epoch = maxi(0, int(payload.get("market_epoch", 0)))
	_sequence = maxi(0, int(payload.get("sequence", 0)))
	pending_race = _dictionary(payload.get("pending_race", {})).duplicate(true)
	last_race = _dictionary(payload.get("last_race", {})).duplicate(true)
	records = _dictionary(payload.get("records", {})).duplicate(true)
	championship = _dictionary(payload.get("championship", {})).duplicate(true)
	_rival_cars = _dictionary(payload.get("rival_cars", {})).duplicate(true)

func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func _next_id(prefix: String) -> String:
	_sequence += 1
	return "%s%06d" % [prefix, _sequence]

func _round_price(value: float) -> int:
	return roundi(value / 10.0) * 10

func _commit(previous: Dictionary, response: Dictionary) -> Dictionary:
	if not save_game():
		_apply(previous)
		return _fail("O jogo não conseguiu gravar a alteração. Tente novamente.")
	changed.emit()
	return response

func _ok(message: String, data: Dictionary = {}) -> Dictionary:
	var response := {"ok": true, "message": message}
	response.merge(data)
	return response

func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
