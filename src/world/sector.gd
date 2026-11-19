extends Node3D
## Positions, props and interactions for the four independent walkable maps.

const Geometry = preload("res://src/world/sector_geometry.gd")
const Person = preload("res://src/world/person_art.gd")
const CarArt = preload("res://src/art/car_art.gd")
const Catalog = preload("res://src/domain/catalog.gd")
const Ui = preload("res://src/ui/ui_kit.gd")

const PAPER := Color("#e8e0c4")
const STEEL := Color("#39444a")
const STEEL_DARK := Color("#252f36")
const CONCRETE := Color("#787b72")
const LIME := Color("#d7ec60")
const AMBER := Color("#eab474")
const BLUE := Color("#6aa7ba")
const DEALER_X := [-3.9, 3.9, -11.7, 11.7, 18.6]

class Target:
	var kind: String
	var key: String
	var title: String
	var action: String
	var position: Vector3
	var reach: float
	var body: StaticBody3D

	func _init(type: String, id: String, text: String, verb: String, at: Vector3, radius: float, collider: StaticBody3D) -> void:
		kind = type
		key = id
		title = text
		action = verb
		position = at
		reach = radius
		body = collider

var id: String
var spawn: Vector3
var spawn_yaw := 0.0
var targets: Array[Target] = []
var fleet: Dictionary = {}
var signature: int
var _geo: Geometry
var _state: Node
var _people: Array[Person] = []
var _vehicle_range: float


func build(district: String, state: Node) -> void:
	id = district
	name = str(Catalog.SECTORS[district].name)
	_state = state
	signature = population_signature(district, state)
	_vehicle_range = {"low": 26.0, "high": 49.0}.get(str(state.settings.quality), 37.0)
	_geo = Geometry.new()
	add_child(_geo)
	match district:
		"garage": _garage()
		"meet": _meet()
		"official": _official()
		"market": _market()
	_geo.finish()


static func population_signature(district: String, state: Node) -> int:
	var quality: String = str(state.settings.quality)
	match district:
		"garage":
			var parked: Array = []
			for car: Dictionary in state.cars:
				parked.append([car.uid, car.model, car.color])
			return hash([quality, parked, state.active_uid])
		"meet": return hash([quality, state.rival_garage()])
		"official": return hash([quality, state.active_car(), state.championship, state.reputation])
		"market": return hash([quality, state.market_list()])
	return 0


func preview_paint(uid: String, swatch: String) -> void:
	var model: Node3D = fleet.get(uid)
	if is_instance_valid(model):
		CarArt.set_paint(model, Color.from_string(swatch, PAPER))


func animate_people(delta: float, observer: Vector3) -> void:
	for person in _people:
		if person.global_position.distance_squared_to(observer) < 26.0 * 26.0:
			person.animate(delta, 0.0)


func _garage() -> void:
	spawn = Vector3(-0.65, 0.03, 7.2)
	_atmosphere(Color("#4b6976"), Color("#819caa"), Color("#f9e7c9"), 0.76, 0.77, 0.0)
	_geo.surface(Vector3(0, 0, 0.5), Vector3(23, 0, 26), Color("#626663"))
	_room_wall(Vector3(-11.5, 2.4, 0.5), Vector3(0.38, 4.8, 26), Color("#435157"), BLUE)
	_room_wall(Vector3(11.5, 2.4, 0.5), Vector3(0.38, 4.8, 26), Color("#435157"), BLUE)
	_room_wall(Vector3(0, 2.4, 13.5), Vector3(23, 4.8, 0.38), Color("#354148"), BLUE)
	_geo.box(Vector3(0, 4.88, 0.5), Vector3(23, 0.25, 26), STEEL_DARK, true)
	for z in [9.6, 4.7, -0.15, -5.0, -9.85]:
		_geo.box(Vector3(0, 4.61, z), Vector3(23, 0.33, 0.23), Color("#26343a"))
		for x in [-5.7, 0.0, 5.7]:
			_geo.box(Vector3(x, 4.43, z), Vector3(3.6, 0.10, 0.44), STEEL)
			_geo.light_strip(Vector3(x, 4.36, z), Vector3(3.42, 0.042, 0.32), Color("#eeeee0"))
		for x in [-11.12, 11.12]:
			_geo.box(Vector3(x, 2.40, z), Vector3(0.29, 4.76, 0.27), STEEL_DARK)
			_geo.box(Vector3(x * 0.991, 0.40, z), Vector3(0.32, 0.8, 0.28), AMBER)
	for z in range(-11, 11, 2):
		for x in [-1.85, 1.85]:
			_geo.box(Vector3(x, 0.012, z), Vector3(0.055, 0.009, 1.02), PAPER.darkened(0.33))

	var extra := maxi(0, int(_state.cars.size()) - 6)
	if extra == 0:
		_room_wall(Vector3(0, 2.4, -12.5), Vector3(23, 4.8, 0.38), Color("#3b4a50"), BLUE)
		_geo.box(Vector3(0, 1.64, -12.25), Vector3(5.8, 3.27, 0.19), Color("#52646b"), true)
		for strip in 12:
			_geo.box(Vector3(0, 0.12 + float(strip) * 0.26, -12.14), Vector3(5.6, 0.025, 0.026), STEEL_DARK)
	else:
		for side in [-1.0, 1.0]:
			_room_wall(Vector3(side * 7.35, 2.4, -12.5), Vector3(8.3, 4.8, 0.38), Color("#3b4a50"), BLUE)
		_garage_annex(ceili(float(extra) / 8.0))
	_wall_sign("OFICINA RIBEIRA", Vector3(0, 3.94, -12.12), 8.2, LIME, 0.011)
	_wall_sign("COLEÇÃO", Vector3(0, 3.48, -12.08), 3.64, PAPER, 0.007)
	_garage_workshop()
	_omni(Vector3(-7.4, 3.65, 2.45), Color("#ffce9c"), 1.40, 9.0)
	_omni(Vector3(6.2, 3.78, 3.60), Color("#c7f7f4"), 1.25, 9.0)
	_directory(Vector3(8.85, 0, -6.5), -0.11)
	_wall_sign("SAÍDA", Vector3(7.65, 3.5, -12.1), 3.5, LIME, 0.011)
	for row in 3:
		for side in [-1.0, 1.0]:
			_parking_outline(Vector3(side * 4.9, 0.02, 1.10 - float(row) * 5.0), side * PI * 0.5, BLUE.darkened(0.2))
	for i in _state.cars.size():
		var car: Dictionary = _state.cars[i]
		var spec := Catalog.effective(car)
		var active := str(car.uid) == str(_state.active_uid)
		var at: Vector3
		var yaw: float
		if i < 6:
			var side := -1.0 if i % 2 == 0 else 1.0
			at = Vector3(side * 4.9, 0.02, 1.10 - floorf(float(i) / 2.0) * 5.0)
			yaw = side * PI * 0.5
			if active:
				_parking_outline(at + Vector3(0, 0.007, 0), yaw, LIME)
		else:
			var slot := int(i) - 6
			at = Vector3((float(slot % 8) - 3.5) * 5.2, 0.02, -18.7 - floorf(float(slot) / 8.0) * 7.65)
			yaw = PI
			if active:
				_parking_outline(at, yaw, LIME)
		var body := _park(spec, at, yaw, active, str(car.uid))
		var title := str(spec.name)
		if active:
			title += " · Ativo"
		_target("car", str(car.uid), title, "Ver carro", at + Vector3(0, 0.82, 0), 3.35, body)
		_car_plate(at, yaw, str(spec.name), LIME if active else PAPER)
		if active:
			var active_board := at + Vector3(0.0, 1.85, 0.0)
			var label := _geo.sign("CARRO ATIVO", active_board, 0.0047, LIME)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.outline_size = 10
			label.outline_modulate = Color("#252e34")
			label.visibility_range_end = 12.0


func _garage_annex(rows: int) -> void:
	var length := float(rows) * 7.65 + 5.0
	var center := -12.5 - length * 0.5
	_geo.surface(Vector3(0, 0, center), Vector3(43.6, 0, length), Color("#5d645f"))
	_geo.box(Vector3(0, 4.78, center), Vector3(43.6, 0.32, length), STEEL_DARK, true)
	for side in [-1.0, 1.0]:
		_room_wall(Vector3(21.8 * side, 2.4, center), Vector3(0.35, 4.8, length), STEEL, BLUE)
		_room_wall(Vector3(16.75 * side, 2.4, -12.5), Vector3(10.2, 4.8, 0.33), STEEL, BLUE)
	_room_wall(Vector3(0, 2.4, -12.5 - length), Vector3(43.6, 4.8, 0.35), STEEL, BLUE)
	for row in rows:
		var z := -18.7 - float(row) * 7.65
		_geo.box(Vector3(0, 4.59, z), Vector3(43.6, 0.23, 0.28), STEEL)
		for x in [-16.0, -8.0, 0.0, 8.0, 16.0]:
			_geo.light_strip(Vector3(x, 4.40, z), Vector3(4.2, 0.08, 0.22), PAPER)
		for slot in 8:
			var at := Vector3((float(slot) - 3.5) * 5.2, 0, z)
			_parking_outline(at, PI, BLUE.darkened(0.2))
		_geo.box(Vector3(0, 0.015, z + 3.47), Vector3(42, 0.01, 0.05), BLUE.darkened(0.39))


func _garage_workshop() -> void:
	_counter(Vector3(-9.0, 0, 3.74), 3.6, PI * 0.5, BLUE)
	_tires(Vector3(-9.35, 0, 1.37), 3)
	_geo.box(Vector3(-10.97, 1.97, 3.67), Vector3(0.11, 1.37, 4.06), Color("#6f7c74"))
	for i in 6:
		var z := 2.24 + float(i) * 0.47
		_geo.box(Vector3(-10.88, 2.13, z), Vector3(0.05, 0.42 + float(i % 3) * 0.09, 0.048), PAPER)
		_geo.box(Vector3(-10.87, 2.30 + float(i % 3) * 0.04, z), Vector3(0.048, 0.055, 0.17), STEEL_DARK)
	_wall_sign("MECÂNICA", Vector3(-10.8, 3.25, 3.74), 3.65, LIME, 0.009, PI * 0.5)
	var mechanic := Vector3(-7.82, 0, 4.5)
	var npc := _person(mechanic, 1, -PI * 0.5)
	_target("tune", "", "Bancada de mecânica", "Abrir oficina", mechanic + Vector3.UP, 2.3, npc)
	_geo.box(Vector3(9.22, 1.71, 0.2), Vector3(0.13, 2.7, 4.2), Color("#637a7d"), true)
	_geo.box(Vector3(8.75, 3.25, 0.2), Vector3(1.06, 0.24, 4.34), STEEL_DARK)
	_geo.light_strip(Vector3(8.50, 3.10, 0.2), Vector3(0.18, 0.065, 3.68), Color("#c9eee6"))
	_geo.light_strip(Vector3(9.12, 2.82, 0.2), Vector3(0.06, 0.045, 3.45), Color("#d2ecea"))
	_wall_sign("PINTURA", Vector3(9.10, 2.30, 0.18), 3.45, PAPER, 0.009, -PI * 0.5)
	var stage_colors: Array = Catalog.COLORS.values()
	for col in 5:
		for row in 2:
			var tint := Color(str(stage_colors[row * 5 + col]))
			_geo.box(Vector3(9.12, 1.27 + float(row) * 0.31, -0.84 + float(col) * 0.47), Vector3(0.065, 0.24, 0.32), tint)
	_target("paint", "", "Bancada de pintura", "Ver cores", Vector3(8.88, 0.95, 0.2), 2.05)
	_geo.box(Vector3(10.7, 1.21, 4.35), Vector3(1.04, 2.36, 2.85), Color("#4e737a"), true)
	for z in [3.89, 4.82]:
		_geo.box(Vector3(10.13, 1.32, z), Vector3(0.065, 1.95, 0.027), STEEL_DARK)
		_geo.box(Vector3(10.09, 1.35, z + 0.16), Vector3(0.068, 0.32, 0.043), PAPER)
	_geo.box(Vector3(-10.61, 1.38, -4.60), Vector3(0.73, 2.70, 3.83), STEEL_DARK, true)
	for shelf in 3:
		var level := 0.22 + float(shelf) * 0.81
		_geo.box(Vector3(-10.12, level, -4.60), Vector3(0.32, 0.095, 3.66), BLUE)
		for crate in 4:
			var tint := Color("#596965") if (crate + shelf) % 2 == 0 else Color("#a08465")
			_geo.box(Vector3(-10.16, level + 0.23, -5.99 + float(crate) * 0.91), Vector3(0.37, 0.38, 0.72), tint)
	_terminal(Vector3(-8.68, 0, -8.6), 0.34, "QUADRO DE METAS", BLUE)
	_target("goals", "", "Quadro de metas", "Consultar metas", Vector3(-8.48, 0.9, -8.02), 2.20)


func _meet() -> void:
	spawn = Vector3(0, 0.03, 8.3)
	_atmosphere(Color("#192d50"), Color("#505474"), Color("#f6caa2"), 0.78, 0.78, 0.006)
	_geo.surface(Vector3(0, 0, -5.0), Vector3(54, 0, 39), Color("#53595c"))
	_geo.surface(Vector3(0, -0.82, -36), Vector3(120, 0, 28), Color("#26424f"))
	_fence(Vector3(0, 0, -24.15), 54.0)
	for x in [-26.85, 26.85]:
		_geo.box(Vector3(x, 0.69, -5.0), Vector3(0.23, 1.38, 39), Color("#32454f"), true)
	_geo.box(Vector3(0, 0.62, 14.35), Vector3(54, 1.25, 0.28), STEEL_DARK, true)
	for x in [-20.5, -11.9, 10.9, 20.4]:
		_container(Vector3(x, 0.0, -20.8), 5.9, Color("#895448") if x < 0 else Color("#4c6877"))
	_container(Vector3(-23.8, 2.43, -20.1), 5.25, Color("#60494b"))
	_container(Vector3(21.8, 2.43, -20.6), 6.5, Color("#687270"))
	for x in [-23.7, -10.0, 10.0, 23.7]:
		_lamp(Vector3(x, 0, -7.6), AMBER, 4.65)
	for x in [-9.7, 9.7]:
		_lamp(Vector3(x, 0, 5.85), AMBER, 4.65)
		_omni(Vector3(x, 4.25, 3.75), Color("#ffd394"), 2.25, 12.0)
	_omni(Vector3(0, 4.5, -12.7), Color("#aac9ff"), 1.75, 17.0)
	for x in [-12.4, 12.4]:
		_crane(Vector3(x, -0.75, -30.0), x < 0)
		_hill(Vector3(x * 2.8, -1.1, -61), 18.0, 8.0, Color("#46536a"))
	_geo.box(Vector3(0, 2.8, -17.45), Vector3(10.7, 0.83, 0.24), STEEL_DARK)
	for x in [-5.2, 5.2]:
		_geo.box(Vector3(x, 1.18, -17.45), Vector3(0.16, 2.42, 0.22), STEEL_DARK, true)
		_geo.light_strip(Vector3(x, 2.78, -17.30), Vector3(0.09, 0.50, 0.05), AMBER)
	_geo.sign("PORTO DA VIGÍLIA", Vector3(0, 2.85, -17.30), 0.0123, PAPER)
	_geo.sign("PONTO DE ENCONTRO", Vector3(0, 2.49, -17.30), 0.0053, AMBER)
	_counter(Vector3(-9.3, 0, 8.8), 3.4, 0.2, AMBER)
	_geo.box(Vector3(-9.25, 2.55, 7.95), Vector3(4.0, 0.17, 2.6), Color("#92584a"))
	_geo.light_strip(Vector3(-9.25, 2.44, 9.03), Vector3(2.8, 0.06, 0.09), AMBER)
	for x in [-20.8, -17.9, -14.9]:
		_geo.cylinder(Vector3(x, 0.35, 7.15), 0.35, 0.70, Color("#a46651"))
		_geo.cylinder(Vector3(x, 0.71, 7.15), 0.38, 0.07, AMBER.darkened(0.2))
		_geo.box(Vector3(x + 0.81, 0.23, 7.10), Vector3(0.40, 0.46, 0.43), STEEL_DARK, true)
	_tires(Vector3(12.0, 0, 8.8), 2)
	_directory(Vector3(4.3, 0, 5.1), -0.23)
	for z in range(-22, 10, 3):
		for x in [-2.4, 2.4]:
			_geo.box(Vector3(x, 0.017, z), Vector3(0.12, 0.012, 1.25), AMBER.darkened(0.17))

	var cars: Dictionary = _state.rival_garage()
	for i in Catalog.NPCS.size():
		var npc_id: String = Catalog.NPCS.keys()[i]
		var rival := Catalog.npc(npc_id)
		var x: float = [-21.0, -14.2, -7.4, 7.0, 13.8, 20.6][i % 6]
		var z := -1.0 - floorf(float(i) / 6.0) * 10.8
		var at := Vector3(x, 0.02, z)
		var yaw := PI - 0.25 * signf(x)
		_park(cars.get(npc_id, {}), at, yaw, false, npc_id)
		_parking_outline(at, yaw, AMBER.darkened(0.28))
		var npc_pos := at + Vector3(-2.15 * signf(x), 0, 1.58)
		var body := _person(npc_pos, i, PI + 0.38 * signf(x))
		_target("rival", npc_id, str(rival.name), "Conversar", npc_pos + Vector3.UP, 2.55, body)
		_name_label(str(rival.name), npc_pos, AMBER)


func _official() -> void:
	spawn = Vector3(0, 0.03, 8.7)
	_atmosphere(Color("#447a91"), Color("#b0c3bd"), Color("#fff0d1"), 0.73, 1.12, 0.003)
	_geo.surface(Vector3(0, 0, -4.0), Vector3(44, 0, 36), CONCRETE)
	_fence(Vector3(0, 0, -21.6), 44.0)
	_geo.box(Vector3(0, 0.64, 13.9), Vector3(44, 1.28, 0.25), STEEL_DARK, true)
	for x in [-21.9, 21.9]:
		_geo.box(Vector3(x, 0.64, -4), Vector3(0.24, 1.28, 36), STEEL_DARK, true)
		_geo.box(Vector3(x, 0.68, -4), Vector3(0.27, 0.22, 36), LIME.darkened(0.13))
	_geo.surface(Vector3(0, -0.08, -34.0), Vector3(84, 0, 24), Color("#657663"))
	_geo.box(Vector3(0, -0.03, -27.0), Vector3(84, 0.04, 5.8), Color("#343c43"))
	for x in range(-36, 39, 4):
		_geo.box(Vector3(x, 0.008, -27.0), Vector3(2.1, 0.01, 0.08), PAPER)
	_grandstand(Vector3(-5.0, 0.13, -40.0))
	_hill(Vector3(32, -2.0, -63), 20.0, 12.0, Color("#628173"))
	_hill(Vector3(-36, -2.0, -65), 20.0, 11.0, Color("#6f8b77"))
	_geo.box(Vector3(0, 3.04, -16.75), Vector3(18.0, 0.97, 0.32), Color("#243d4a"))
	for x in [-8.65, 8.65]:
		_geo.box(Vector3(x, 1.32, -16.75), Vector3(0.28, 2.66, 0.26), BLUE, true)
	for x in [-7.9, 7.9]:
		for i in 3:
			for j in 2:
				if (i + j) % 2 == 0:
					_geo.box(Vector3(x + 0.20 * (float(i) - 1.0), 2.91 + float(j) * 0.22, -16.57), Vector3(0.20, 0.22, 0.02), LIME)
	_geo.sign("PADDOCK CANDEIA", Vector3(0, 3.14, -16.53), 0.0145, PAPER)
	_geo.sign("CENTRO DE COMPETIÇÕES", Vector3(0, 2.69, -16.53), 0.0058, LIME)
	_pit_shelter(Vector3(-17.30, 0, -9.8), "OFICIAIS", BLUE)
	_pit_shelter(Vector3(16.9, 0, -10.4), "PREPARAÇÃO", Color("#7c9381"))

	for z in range(-18, 12, 3):
		_geo.box(Vector3(0, 0.012, z), Vector3(0.12, 0.012, 1.24), PAPER.darkened(0.22))
	var ordinary := 0
	for event in Catalog.events():
		if bool(event.get("underground", false)):
			continue
		var cup := event.has("series")
		var at: Vector3
		if cup:
			at = Vector3((float(event.round) - 2.0) * 5.8, 0, -12.15)
		else:
			at = Vector3((float(ordinary) - 2.0) * 7.5, 0, -1.6)
			ordinary += 1
		var allowed: bool = _state.event_status(str(event.id)).ok
		_terminal(at, 0.0, str(event.name), LIME if allowed else BLUE, _event_mode(event), float(event.get("reward", 0)))
		_target("event", str(event.id), str(event.name), "Ver inscrição", at + Vector3(0, 0.93, 0.57), 2.4)
	_geo.box(Vector3(0, 2.02, -15.24), Vector3(5.45, 0.62, 0.22), STEEL_DARK)
	_geo.sign("COPA DA ORLA", Vector3(0, 2.12, -15.11), 0.010, LIME)
	var cup_state: Dictionary = _state.championship.get("copa_orla", {})
	_geo.sign("%d / 27 PONTOS" % int(cup_state.get("points", 0)), Vector3(0, 1.88, -15.10), 0.005, PAPER)

	_directory(Vector3(8.8, 0, 4.3), -0.23)
	var car: Dictionary = _state.active_car()
	if not car.is_empty():
		var spec := Catalog.effective(car)
		var at := Vector3(-9.25, 0.02, 5.3)
		var body := _park(spec, at, -0.78, true)
		_parking_outline(at, -0.78, LIME)
		_target("staged_car", str(car.uid), str(spec.name), "Ver carro de prova", at + Vector3(0, 0.7, 0), 3.1, body)
		_car_plate(at, -0.78, "SEU CARRO", LIME)
	_person(Vector3(-13.4, 0, 4.7), 11, -PI * 0.51)
	_person(Vector3(16.05, 0, 2.8), 4, PI * 0.87)
	_person(Vector3(-13.6, 0, -5.4), 6, PI * 0.9)
	_park(Catalog.vehicle("vetra_x"), Vector3(16.75, 0.02, 5.15), -0.13)
	_bollards(Vector3(-19.1, 0, -6.75), 5, BLUE)
	_bollards(Vector3(14.25, 0, -6.75), 5, BLUE)
	_terminal(Vector3(-14.6, 0, -11.3), 0.20, "TREINO LIVRE", BLUE, "PISTA ABERTA")
	_target("practice", "", "Treino livre", "Entrar na pista", Vector3(-14.6, 0.85, -10.75), 2.35)


func _market() -> void:
	spawn = Vector3(0, 0.03, 10.4)
	_atmosphere(Color("#577d98"), Color("#c4a88d"), Color("#ffe1ae"), 0.80, 0.94, 0.004)
	_geo.surface(Vector3(0, 0, -3.0), Vector3(48, 0, 37), Color("#6c7776"))
	_room_wall(Vector3(0, 2.65, -20.2), Vector3(48, 5.3, 0.27), Color("#445c64"), AMBER)
	_geo.box(Vector3(0, 5.12, -11.7), Vector3(45, 0.38, 16.95), STEEL_DARK, true)
	_geo.box(Vector3(0, 4.76, -3.26), Vector3(45, 0.83, 0.25), Color("#344c57"))
	_geo.sign("REVENDA DO CAIS", Vector3(0, 4.78, -3.08), 0.018, PAPER)
	_geo.light_strip(Vector3(0, 4.35, -3.10), Vector3(45.0, 0.055, 0.068), AMBER)
	_omni(Vector3(-4.2, 4.1, -7.8), Color("#bfeff1"), 1.27, 15.0)
	_omni(Vector3(4.2, 4.1, -7.8), Color("#ffe2c2"), 1.27, 15.0)
	_geo.box(Vector3(0, 0.59, 15.28), Vector3(48, 1.18, 0.3), STEEL_DARK, true)
	for side in [-1.0, 1.0]:
		_geo.box(Vector3(side * 23.87, 0.61, -3.0), Vector3(0.25, 1.22, 37), STEEL_DARK, true)
		for z in [-4.0, -10.8, -17.7]:
			_geo.box(Vector3(side * 21.9, 2.50, z), Vector3(0.27, 5.0, 0.38), Color("#516c72"), true)
			_geo.box(Vector3(side * 21.9, 0.47, z), Vector3(0.36, 0.94, 0.48), AMBER.darkened(0.1))
	for z in [-4.3, -9.8, -15.3]:
		for x in [-17.1, -8.5, 0.0, 8.5, 17.1]:
			_geo.light_strip(Vector3(x, 4.88, z), Vector3(5.25, 0.045, 0.23), Color("#efffe1"))
	for x in range(-20, 21, 5):
		_geo.box(Vector3(x, 2.56, -19.97), Vector3(4.45, 1.50, 0.096), Color("#698991"))
		_geo.box(Vector3(x - 1.31, 2.56, -19.90), Vector3(0.07, 1.50, 0.034), Color("#b5c3bd"))
		_geo.box(Vector3(x + 1.31, 2.56, -19.90), Vector3(0.07, 1.50, 0.034), Color("#b5c3bd"))
	for x in [-20.1, 20.1]:
		_bollards(Vector3(x - 2.1, 0, 5.0), 3, AMBER)

	for x in [-12.1, 12.1]:
		_wall_sign("PARTICULARES", Vector3(x, 2.75, 9.35), 5.2, AMBER, 0.009)
		for side in [-1.0, 1.0]:
			_geo.box(Vector3(x + side * 2.45, 1.37, 9.29), Vector3(0.15, 2.73, 0.16), STEEL, true)
	_wall_sign("AVALIAÇÃO", Vector3(20.1, 2.15, 1.45), 3.73, AMBER, 0.008, -0.4)
	_geo.box(Vector3(20.1, 3.12, 0.98), Vector3(5.2, 0.19, 3.14), Color("#597981"))
	for x in [17.75, 22.45]:
		_geo.box(Vector3(x, 1.55, 0.01), Vector3(0.14, 3.12, 0.15), STEEL, true)
	_counter(Vector3(20.1, 0, 1.32), 3.15, -0.4, AMBER)
	var seller := Vector3(19.8, 0, 2.43)
	var staff := _person(seller, 3, PI - 0.4)
	_target("sell", "", "Balcão de avaliação", "Negociar venda", seller + Vector3.UP, 2.45, staff)
	_directory(Vector3(4.1, 0, 8.45), -0.23)
	for i in 10:
		var at := _dealer_bay(i)
		_parking_outline(at, PI, PAPER.darkened(0.35))

	var private_slots := [-16.0, -8.15, 8.15, 16.0]
	var booths := 0
	var catalogs: Array = Catalog.VEHICLES.keys()
	var people: Array = Catalog.NPCS.keys()
	for offer: Dictionary in _state.market_list():
		var spec := Catalog.vehicle(str(offer.model))
		spec.color = offer.color
		var private: bool = offer.source == "private"
		var at: Vector3
		if private:
			at = Vector3(float(private_slots[booths]), 0.02, 6.25)
			booths += 1
		else:
			var index := catalogs.find(offer.model)
			at = _dealer_bay(index)
			at.y = 0.02
		var paint := AMBER if private else LIME
		var body := _park(spec, at, PI, false, str(offer.id))
		if private:
			_parking_outline(at, PI, AMBER.darkened(0.15))
			var npc_pos := at + Vector3(2.1 * signf(at.x), 0, 1.12)
			_person(npc_pos, people.find(offer.npc_id), PI)
			_name_label(str(Catalog.npc(offer.npc_id).name), npc_pos, AMBER)
		_car_plate(at, PI, "%s  /  %s" % [spec.name, Ui.money(int(offer.asking))], paint)
		_target("offer", str(offer.id), str(spec.name), "Negociar" if private else "Ver oferta",
			at + Vector3(0, 0.78, 0), 3.25, body)


func _dealer_bay(slot: int) -> Vector3:
	var row := floorf(float(slot) / 5.0)
	return Vector3(float(DEALER_X[slot % 5]) * (1.0 if row == 0.0 else -1.0), 0, -5.25 - row * 9.0)


func _target(kind: String, key: String, title: String, action: String, at: Vector3, reach: float, body: StaticBody3D = null) -> void:
	targets.append(Target.new(kind, key, title, action, at, reach, body))


func _park(spec: Dictionary, at: Vector3, yaw: float, active := false, key := "") -> StaticBody3D:
	var car := CarArt.create(spec, 1 if active else 0, true)
	car.position = at
	car.rotation.y = yaw
	car.name = str(spec.get("name", "Carro")).replace(".", "_")
	car.set_meta("model", str(spec.get("model", "")))
	add_child(car)
	var dimensions := CarArt.dimensions(spec)
	for mesh: GeometryInstance3D in car.find_children("*", "GeometryInstance3D", true, false):
		mesh.visibility_range_end = _vehicle_range
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow := Geometry.shadow(dimensions.x * 1.65, dimensions.z * 1.29)
	shadow.position.y = 0.006
	shadow.visibility_range_end = _vehicle_range - 4.0
	car.add_child(shadow)
	var body := Geometry.collision_box(car, Vector3(0, dimensions.y * 0.38, 0),
		Vector3(dimensions.x * 1.04, dimensions.y * 0.75, dimensions.z * 0.99))
	if not key.is_empty():
		fleet[key] = car
	return body


func _person(at: Vector3, palette: int, yaw: float) -> StaticBody3D:
	var actor := Person.new()
	actor.position = at
	actor.rotation.y = yaw
	add_child(actor)
	actor.build(palette)
	_people.append(actor)
	return Geometry.collision_box(actor, Vector3(0, 0.88, 0), Vector3(0.67, 1.7, 0.54))


func _name_label(words: String, at: Vector3, ink: Color) -> void:
	var tag := _geo.sign(words, at + Vector3.UP * 2.08, 0.0041, ink)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.outline_size = 10
	tag.outline_modulate = Color("#283039")
	tag.visibility_range_end = 9.0


func _parking_outline(at: Vector3, yaw: float, color: Color) -> void:
	var foot := Vector3(at.x, 0.017 + at.y, at.z)
	for side in [-1.0, 1.0]:
		var rail := Vector3(side * 1.51, 0, 0).rotated(Vector3.UP, yaw)
		_geo.box(foot + rail, Vector3(0.056, 0.012, 5.12), color, false, yaw)
	var tail := Vector3(0, 0, 2.52).rotated(Vector3.UP, yaw)
	_geo.box(foot + tail, Vector3(3.06, 0.012, 0.07), color, false, yaw)
	var stop := Vector3(0, 0, -2.39).rotated(Vector3.UP, yaw)
	_geo.box(foot + stop, Vector3(1.23, 0.014, 0.12), color, false, yaw)


func _car_plate(at: Vector3, yaw: float, words: String, ink: Color) -> void:
	var position := at + Vector3(0, 0, -2.88).rotated(Vector3.UP, yaw)
	var label := _geo.sign(words, position + Vector3(0, 0.39, 0), 0.0038, ink)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 11
	label.outline_modulate = STEEL_DARK
	label.visibility_range_end = 9.5


func _directory(at: Vector3, yaw: float) -> void:
	_terminal(at, yaw, "SAÍDA", LIME, "BAÍA DO SAL")
	var front := Vector3(0, 0.92, 0.60).rotated(Vector3.UP, yaw)
	_target("travel", "", "Saída para Baía do Sal", "Viajar", at + front, 2.68)
	for side in [-1.0, 1.0]:
		var at_strip := at + Vector3(side * 1.68, 0.018, 0.50).rotated(Vector3.UP, yaw)
		_geo.box(at_strip, Vector3(0.10, 0.016, 1.58), LIME, false, yaw)


func _terminal(at: Vector3, yaw: float, title: String, ink: Color, subtitle := "", reward := 0.0) -> void:
	var orient := Basis(Vector3.UP, yaw)
	var shade := Geometry.shadow(2.95, 1.54)
	shade.position = at + Vector3(0.02, 0.021, 0.04)
	shade.rotation.y = yaw
	_geo.add_child(shade)
	_geo.box(at + Vector3.UP * 0.10, Vector3(2.18, 0.20, 0.92), STEEL_DARK, true, yaw)
	_geo.box(at + Vector3.UP * 0.61, Vector3(0.54, 0.99, 0.56), Color("#516168"), true, yaw)
	_geo.box(at + Vector3.UP * 1.34, Vector3(2.20, 0.69, 0.19), Color("#1b2930"), true, yaw)
	_geo.light_strip(at + orient * Vector3(-1.015, 1.34, 0.109), Vector3(0.075, 0.64, 0.012), ink, yaw)
	var title_width := Ui.DISPLAY.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 58).x
	_geo.sign(title, at + orient * Vector3(0.031, 1.44, 0.112), minf(0.0070, 1.87 / maxf(1.0, title_width)), PAPER, yaw)
	if not subtitle.is_empty() or reward > 0.0:
		var detail := subtitle if reward <= 0.0 else "%s · %s" % [subtitle, Ui.money(int(reward))]
		var detail_width := Ui.DISPLAY.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 58).x
		_geo.sign(detail, at + orient * Vector3(0.034, 1.17, 0.113), minf(0.0043, 1.87 / maxf(1.0, detail_width)), ink, yaw)


func _event_mode(event: Dictionary) -> String:
	match str(event.mode):
		"sprint": return "SPRINT"
		"drag": return "ARRANCADA"
		"time_trial": return "TEMPO"
	return "CIRCUITO"


func _pit_shelter(at: Vector3, plaque: String, ink: Color) -> void:
	_geo.box(at + Vector3(0, 1.43, -2.05), Vector3(6.3, 2.86, 0.31), STEEL, true)
	_geo.box(at + Vector3(0, 2.89, 0), Vector3(6.55, 0.26, 4.36), STEEL_DARK)
	for side in [-1.0, 1.0]:
		_geo.box(at + Vector3(side * 3.04, 1.43, 1.97), Vector3(0.24, 2.86, 0.25), ink, true)
		_geo.box(at + Vector3(side * 3.03, 0.26, 0.7), Vector3(0.07, 0.02, 2.45), ink)
	_geo.box(at + Vector3(0, 2.84, 2.18), Vector3(6.78, 0.32, 0.07), ink)
	_geo.sign(plaque, at + Vector3(0, 2.83, 2.23), 0.0074, STEEL_DARK)
	_geo.light_strip(at + Vector3(0, 2.71, 0.75), Vector3(4.19, 0.07, 0.17), PAPER)
	_counter(at + Vector3(0, 0, -0.45), 3.55, 0, ink)


func _counter(at: Vector3, span: float, yaw: float, ink: Color) -> void:
	var orient := Basis(Vector3.UP, yaw)
	_geo.box(at + Vector3.UP * 0.46, Vector3(span, 0.89, 0.62), STEEL_DARK, true, yaw)
	_geo.box(at + Vector3.UP * 0.92, Vector3(span + 0.14, 0.12, 0.74), Color("#88918b"), true, yaw)
	_geo.box(at + orient * Vector3(0, 0.83, 0.324), Vector3(span, 0.045, 0.01), ink, false, yaw)
	for i in 3:
		_geo.box(at + orient * Vector3(0.0, 0.28 + float(i) * 0.17, 0.328), Vector3(span * 0.90, 0.035, 0.021), STEEL, false, yaw)
	_geo.box(at + orient * Vector3(-span * 0.21, 1.016, 0.015), Vector3(0.34, 0.12, 0.28), BLUE, false, yaw)
	_geo.box(at + orient * Vector3(span * 0.26, 1.044, -0.09), Vector3(0.52, 0.19, 0.30), STEEL_DARK, false, yaw)


func _room_wall(at: Vector3, dimensions: Vector3, tint: Color, stripe: Color) -> void:
	_geo.box(at, dimensions, tint, true)
	_geo.box(Vector3(at.x, 0.60, at.z), Vector3(dimensions.x + 0.025, 1.2, dimensions.z + 0.025), STEEL_DARK)
	_geo.box(Vector3(at.x, 1.25, at.z), Vector3(dimensions.x + 0.044, 0.055, dimensions.z + 0.044), stripe)


func _wall_sign(words: String, at: Vector3, width: float, ink: Color, scale: float, yaw := 0.0) -> void:
	var back := Vector3(0, 0, -0.075).rotated(Vector3.UP, yaw)
	_geo.box(at + back, Vector3(width, 0.66, 0.13), STEEL_DARK, false, yaw)
	_geo.sign(words, at, scale, ink, yaw)


func _fence(at: Vector3, width: float) -> void:
	_geo.box(at + Vector3.UP * 0.53, Vector3(width, 1.06, 0.25), Color("#394951"), true)
	for y in [0.22, 0.60, 1.02]:
		_geo.box(at + Vector3(0, y, 0.145), Vector3(width, 0.066, 0.045), Color("#697572"))
	for post in ceili(width / 3.0):
		var x := -width * 0.5 + float(post) * 3.0 + 1.35
		_geo.box(at + Vector3(x, 0.66, 0.19), Vector3(0.10, 1.32, 0.13), AMBER.darkened(0.19))


func _container(at: Vector3, width: float, tint: Color) -> void:
	_geo.box(at + Vector3.UP * 1.21, Vector3(width, 2.42, 2.26), tint, true)
	for x in range(-int(width * 4.0) + 2, int(width * 4.0), 2):
		_geo.box(at + Vector3(float(x) * 0.125, 1.20, 1.142), Vector3(0.054, 2.20, 0.046), tint.darkened(0.19))
	for y in [0.17, 2.23]:
		_geo.box(at + Vector3(0, y, 1.17), Vector3(width, 0.096, 0.064), tint.darkened(0.30))


func _tire_color() -> Color:
	return Color("#272d33")


func _tires(at: Vector3, height: int) -> void:
	for i in height:
		var tire := _geo.cylinder(at + Vector3.UP * (0.13 + float(i) * 0.23), 0.40, 0.216, _tire_color())
		tire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geo.cylinder(at + Vector3.UP * (float(height) * 0.23 + 0.009), 0.236, 0.03, Color("#121e24"))


func _lamp(at: Vector3, ink: Color, height: float) -> void:
	_geo.box(at + Vector3.UP * (height * 0.5), Vector3(0.10, height, 0.10), STEEL_DARK, true)
	_geo.box(at + Vector3(0, height - 0.08, 0.43), Vector3(0.28, 0.14, 0.85), STEEL_DARK)
	_geo.light_strip(at + Vector3(0, height - 0.16, 0.65), Vector3(0.25, 0.042, 0.36), ink)


func _bollards(at: Vector3, count: int, ink: Color) -> void:
	for i in count:
		var post := at + Vector3(1.27 * float(i), 0.44, 0)
		_geo.box(post, Vector3(0.25, 0.88, 0.25), STEEL, true)
		_geo.box(post + Vector3.UP * 0.34, Vector3(0.267, 0.13, 0.267), ink)


func _crane(at: Vector3, mirror: bool) -> void:
	var sign_x := -1.0 if mirror else 1.0
	var paint := Color("#444958")
	for x in [-3.25, 3.25]:
		_geo.box(at + Vector3(x, 4.4, 0), Vector3(0.62, 8.8, 0.61), paint)
		_geo.box(at + Vector3(x, 2.8, -2.2), Vector3(0.62, 5.6, 0.61), paint)
	_geo.box(at + Vector3(sign_x * 2.0, 8.96, 0.0), Vector3(17.1, 0.49, 0.78), paint)
	_geo.box(at + Vector3(sign_x * 8.65, 7.2, 0.0), Vector3(0.070, 3.5, 0.065), paint.darkened(0.4))
	_geo.box(at + Vector3(sign_x * 8.65, 5.40, 0.0), Vector3(0.37, 0.25, 0.35), paint)
	_geo.light_strip(at + Vector3(sign_x * 10.3, 9.21, 0), Vector3(0.16, 0.21, 0.15), Color("#ed8c70"))


func _grandstand(at: Vector3) -> void:
	for row in 6:
		var y := 0.63 + float(row) * 0.43
		var z := -float(row) * 0.92
		_geo.box(at + Vector3(0, y * 0.5, z), Vector3(40.0, y, 1.03), Color("#687472"))
		for x in range(-19, 20, 2):
			var color := BLUE if (x + row) % 3 == 0 else Color("#a8a782")
			_geo.box(at + Vector3(x, y + 0.21, z + 0.13), Vector3(1.32, 0.35, 0.36), color)
	_geo.box(at + Vector3(0, 5.70, -3.15), Vector3(42.5, 0.26, 6.1), Color("#4e6267"))
	for x in [-20.2, -6.8, 6.8, 20.2]:
		_geo.box(at + Vector3(x, 2.85, -5.75), Vector3(0.24, 5.7, 0.22), STEEL_DARK)


func _hill(at: Vector3, radius: float, height: float, tint: Color) -> void:
	var mound := _geo.cylinder(at, radius, height, tint)
	var mesh := mound.mesh as CylinderMesh
	mesh.top_radius = radius * 0.21
	mesh.radial_segments = 7


func _omni(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var fill := OmniLight3D.new()
	fill.position = at
	fill.light_color = color
	fill.light_energy = energy
	fill.omni_range = reach
	fill.omni_attenuation = 1.0
	add_child(fill)


func _atmosphere(top: Color, horizon: Color, sun_color: Color, ambient: float, sun: float, fog: float) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = top
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon
	sky_material.ground_bottom_color = top.darkened(0.4)
	sky_material.sun_angle_max = 7.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var lighting := Environment.new()
	lighting.background_mode = Environment.BG_SKY
	lighting.sky = sky
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color = horizon.lerp(Color("#d6e2e5"), 0.55)
	lighting.ambient_light_energy = ambient
	lighting.fog_enabled = fog > 0.0
	lighting.fog_light_color = horizon
	lighting.fog_density = fog
	var environment := WorldEnvironment.new()
	environment.environment = lighting
	add_child(environment)
	var directional := DirectionalLight3D.new()
	directional.rotation_degrees = Vector3(-48.0, -33.0, 0.0)
	directional.light_color = sun_color
	directional.light_energy = sun
	directional.shadow_enabled = false
	add_child(directional)
