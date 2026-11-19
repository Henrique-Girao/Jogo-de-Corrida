extends SceneTree
## Run with a fresh XDG_DATA_HOME, --fixed-fps 60 and -- --touch-controls.

const Catalog = preload("res://src/domain/catalog.gd")
const CarArt = preload("res://src/art/car_art.gd")

var _world: Node3D
var _game: Node
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data_root := OS.get_environment("XDG_DATA_HOME").simplify_path().trim_suffix("/")
	var user_root := ProjectSettings.globalize_path("user://").simplify_path()
	if data_root.is_empty() or not user_root.begins_with(data_root + "/"):
		push_error("Use um XDG_DATA_HOME temporário para o teste de exploração.")
		quit(1)
		return

	var state := root.get_node("GameState")
	if int(state.stats.races) != 0 or state.cars.size() != 1 or not state.last_race.is_empty():
		push_error("Use um save novo para o teste de exploração.")
		quit(1)
		return

	var old_save: Dictionary = state._snapshot()
	old_save.erase("last_sector")
	old_save.settings.erase("walk_sensitivity")
	state._apply(old_save)
	_check(state.last_sector == "garage" and is_equal_approx(float(state.settings.walk_sensitivity), 1.0), "save antigo migra para a garagem")
	state.money = 900000
	var purchase: Dictionary = state.purchase("dealer:linha_rs")
	if not _check(bool(purchase.ok), "compra de preparação do teste"):
		quit(1)
		return

	_game = (load("res://src/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	Engine.max_fps = 0
	await process_frame
	_world = _game.hub
	var first: Dictionary = state.cars[0]
	var second: Dictionary = state.cars[1]
	var first_uid := str(first.uid)
	var second_uid := str(second.uid)
	_check(_world.sector.fleet.size() == 2, "um modelo físico para cada carro")
	_check(bool(state.select_car(first_uid).ok), "seleção inicial para testar serviço em outro carro")
	await _wait_frames(3)

	_check(await _open("car", second_uid, 3.06), "inspeção do segundo carro por proximidade")
	_press(_world.dialogs, "Pintar este carro")
	var color_name := "Marfim"
	var color: String = Catalog.COLORS[color_name]
	var previous := str(second.color)
	_press(_world.dialogs, color_name)
	_check(_material_color(second_uid).is_equal_approx(Color(color)), "prévia troca a tinta da carroceria no mapa")
	_world.dialogs.close_dialog()
	_check(_material_color(second_uid).is_equal_approx(Color(previous)), "cancelamento restaura a pintura")
	_check(str(state.owned_car(second_uid).color) == previous, "prévia não altera o save")

	_check(await _open("car", second_uid, 3.06), "reabertura da inspeção")
	_press(_world.dialogs, "Pintar este carro")
	_press(_world.dialogs, color_name)
	_press(_world.dialogs, "Aplicar pintura")
	await _wait_frames(3)
	_check(str(state.owned_car(second_uid).color) == color and state.active_uid == first_uid, "pintura é aplicada ao carro examinado")
	_check(_material_color(second_uid).is_equal_approx(Color(color)), "a carroceria reflete a pintura persistida")

	var parked: Node3D = _world.sector.fleet[first_uid]
	var start := parked.position + Vector3(3.3, 0, 0)
	_world.player.place(start, 0.0, 0.29)
	_world.player.movement = Vector2.LEFT
	await _wait_frames(65)
	_world.player.reset_input()
	var margin := float(CarArt.dimensions(first).z) * 0.47
	_check(_world.player.position.x < start.x - 0.65 and _world.player.position.x > parked.position.x + margin, "colisão física com carro estacionado")

	var real_collection: Array = state.cars.duplicate(true)
	for index in range(state.cars.size(), int(state.PURCHASE_LIMIT)):
		var record := first.duplicate(true)
		record.uid = "teste-%d" % index
		state.cars.append(record)
	state.changed.emit()
	await _wait_frames(3)
	var positions: Dictionary = {}
	for car: Node3D in _world.sector.fleet.values():
		positions[Vector2(car.position.x, car.position.z)] = true
	_check(positions.size() == int(state.PURCHASE_LIMIT), "99 veículos com vagas físicas únicas")
	var last_uid := str(state.cars.back().uid)
	_check(await _open("car", last_uid, 3.03), "última vaga do anexo interativa")
	_world.dialogs.close_dialog()
	await _travel("meet")
	_check(_world.sector.fleet.size() == Catalog.NPCS.size(), "encontro tem o carro de cada um dos 12 pilotos")
	for npc_id: String in Catalog.NPCS:
		var car: Node3D = _world.sector.fleet.get(npc_id)
		_check(is_instance_valid(car) and car.get_meta("model") == Catalog.NPCS[npc_id].car, "carro de %s no encontro" % npc_id)
	_check(await _open("rival", "lia"), "conversa ocorre junto à pilota")
	_check(_label(_world.dialogs, "Lia Reis") != null, "diálogo usa a identidade certa")
	_press(_world.dialogs, "Propor duelo")
	_check(_button(_world.dialogs, "Confirmar e correr") != null, "diálogo da pilota oferece aposta funcional")
	_world.dialogs.close_dialog()

	state.cars.assign(real_collection)
	await _travel("market")
	var offers: Array = state.market_list()
	_check(_world.sector.fleet.size() == offers.size(), "ofertas atuais têm carros físicos únicos na revenda")
	var offer_id := str(offers[0].id)
	_check(await _open("offer", offer_id, 3.07), "proposta é aberta ao lado do carro anunciado")
	var count: int = state.cars.size()
	_press(_world.dialogs, "Confirmar compra")
	await _wait_frames(3)
	_check(state.cars.size() == count + 1, "compra no pátio entra na coleção")
	_check(await _open("sell", ""), "balcão físico abre avaliação")
	_check(_button(_world.dialogs, "Negociar") != null, "avaliação lista veículos de propriedade do jogador")
	_world.dialogs.close_dialog()

	await _travel("official")
	_check(await _open("practice", ""), "terminal de treino fica no paddock")
	var at: Vector3 = _world.player.global_position
	var balance: int = state.money
	var records: Dictionary = state.records.duplicate(true)
	_press(_world.dialogs, "Treinar")
	await _wait_frames(3)
	if _check(is_instance_valid(_game.race) and _game.active_ticket.event.mode == "practice", "treino lança uma pista sem inscrição"):
		_game.race._elapsed = 380.0
		_game.race.set_controls(0.0, 1.0, 0.0)
		await _wait_frames(120)
		_check(not _game.race_settled and float(_game.hud.telemetry.speed_kmh) > 15.0, "treino permite condução sem limite de duração")
		_check(state.pending_race.is_empty() and state.money == balance and state.records == records, "treino não muda prêmios nem histórico")
		_game.hud.request_pause()
		_press(_game.hud, "Voltar ao paddock")
		await _wait_frames(3)
		_check(is_instance_valid(_world.sector) and _world.player.global_position.distance_to(at) < 0.35, "sair do treino retorna ao guichê")

	if _failures == 0:
		print("EXPLORATION SMOKE OK | 99 vagas | 12 pilotos | pintura no mapa | compra no pátio | treino livre")
	quit(int(_failures > 0))


func _travel(destination: String) -> void:
	if not await _open("travel", ""):
		_check(false, "a saída precisa abrir opções de viagem")
		return
	var label := _label(_world.dialogs, str(Catalog.SECTORS[destination].name))
	if label == null:
		_check(false, "destino %s listado" % destination)
		return
	_press(label.get_parent().get_parent(), "Viajar")
	await _wait_frames(3)
	_check(_world.sector_id == destination, "viagem para %s" % destination)


func _open(kind: String, key: String, distance: float = 1.35) -> bool:
	for target in _world.sector.targets:
		if target.kind != kind or target.key != key:
			continue
		var point: Vector3 = target.position
		var side := Vector3.BACK
		if kind in ["car", "offer"]:
			var car: Node3D = _world.sector.fleet[key]
			side = Vector3.FORWARD.rotated(Vector3.UP, car.rotation.y)
		var at := Vector3(point.x, 0.035, point.z) + side * distance
		_world.player.place(at, atan2(side.x, side.z), 0.29)
		await _wait_frames(3)
		_world.interact()
		return _world.dialogs.is_open()
	return false


func _material_color(uid: String) -> Color:
	var model: Node3D = _world.sector.fleet[uid]
	return CarArt.paint_tint(model)


func _wait_frames(count: int) -> void:
	for frame in count:
		await process_frame


func _press(parent: Node, title: String) -> void:
	var button := _button(parent, title)
	if _check(is_instance_valid(button) and not button.disabled, "botão %s disponível" % title):
		button.pressed.emit()


func _button(parent: Node, title: String) -> Button:
	if parent is Button and parent.text.begins_with(title):
		return parent
	for child in parent.get_children():
		var button := _button(child, title)
		if button != null:
			return button
	return null


func _label(parent: Node, title: String) -> Label:
	if parent is Label and parent.text == title:
		return parent
	for child in parent.get_children():
		var label := _label(child, title)
		if label != null:
			return label
	return null


func _check(result: bool, description: String) -> bool:
	if not result:
		_failures += 1
		push_error("Exploração: %s" % description)
	return result
