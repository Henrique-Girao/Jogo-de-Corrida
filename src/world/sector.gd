extends Node3D
## Positions, props and interactions for the four independent walkable maps.

const Geometry = preload("res://src/world/sector_geometry.gd")
const Person = preload("res://src/world/person_art.gd")
const CarArt = preload("res://src/art/car_art.gd")
const Style = preload("res://src/art/scene_style.gd")
const Forms = preload("res://src/art/mesh_forms.gd")
const Catalog = preload("res://src/domain/catalog.gd")
const Ui = preload("res://src/ui/ui_kit.gd")

const PAPER := Color("#e8e0c4")
const STEEL := Color("#39444a")
const STEEL_DARK := Color("#252f36")
const LIME := Color("#d9e48a")
const AMBER := Color("#eab474")
const BLUE := Color("#6aa7ba")
const DEALER_X := [-3.9, 3.9, -11.7, 11.7, 18.6]

static var _ridge_mesh: ArrayMesh

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
	_atmosphere(Color("#526d7a"), Color("#b0b4a7"), Color("#f9e8cd"), 0.86, 0.74, 0.0, Vector3(-51, -34, 0), 0.0)
	_geo.surface(Vector3(0, 0, 0.5), Vector3(23, 0, 26), Color("#777872"), "slab", 4.5)
	_room_wall(Vector3(-11.5, 2.4, 0.5), Vector3(0.38, 4.8, 26), Color("#64736f"), BLUE)
	_room_wall(Vector3(11.5, 2.4, 0.5), Vector3(0.38, 4.8, 26), Color("#637c7b"), BLUE)
	_room_wall(Vector3(0, 2.4, 13.5), Vector3(23, 4.8, 0.38), Color("#565e5b"), BLUE)
	_geo.box(Vector3(0, 4.88, 0.5), Vector3(23, 0.25, 26), Color("#454f51"), true)
	for x in [-8.2, 8.2]:
		_geo.box(Vector3(x, 4.60, 0.5), Vector3(0.20, 0.22, 25.75), STEEL)
	for z in [9.6, 4.7, -0.15, -5.0, -9.85]:
		_geo.box(Vector3(0, 4.62, z), Vector3(23, 0.31, 0.22), Color("#374549"))
		for x in [-5.7, 0.0, 5.7]:
			_geo.beveled(Vector3(x, 4.41, z), Vector3(3.5, 0.13, 0.39), Color("#747d79"))
			_geo.light_strip(Vector3(x, 4.334, z), Vector3(3.26, 0.035, 0.255), Color("#fff2d3") if x < 0 else Color("#ecf3ed"))
		for x in [-11.12, 11.12]:
			_geo.box(Vector3(x, 2.40, z), Vector3(0.29, 4.76, 0.27), STEEL_DARK)
			_geo.box(Vector3(x * 0.991, 0.40, z), Vector3(0.32, 0.8, 0.28), AMBER)
	for z in range(-11, 11, 2):
		for x in [-1.85, 1.85]:
			_geo.box(Vector3(x, 0.012, z), Vector3(0.055, 0.009, 1.02), PAPER.darkened(0.33))

	var extra := maxi(0, int(_state.cars.size()) - 6)
	if extra == 0:
		_room_wall(Vector3(0, 2.4, -12.5), Vector3(23, 4.8, 0.38), Color("#647773"), BLUE)
		_geo.box(Vector3(0, 1.63, -12.23), Vector3(6.01, 3.26, 0.20), STEEL_DARK, true)
		for strip in 11:
			_geo.beveled(Vector3(0, 0.145 + float(strip) * 0.268, -12.11), Vector3(5.53, 0.233, 0.102), Color("#607275").lightened(float(strip) * 0.009))
		_geo.box(Vector3(0, 3.19, -12.03), Vector3(5.91, 0.19, 0.23), Color("#394f55"))
		for x in [-2.87, 2.87]:
			_geo.box(Vector3(x, 1.56, -12.03), Vector3(0.13, 3.09, 0.20), Color("#394f55"))
	else:
		for side in [-1.0, 1.0]:
			_room_wall(Vector3(side * 7.35, 2.4, -12.5), Vector3(8.3, 4.8, 0.38), Color("#3b4a50"), BLUE)
		_garage_annex(ceili(float(extra) / 8.0))
	_wall_sign("OFICINA RIBEIRA", Vector3(0, 3.94, -12.12), 8.2, LIME, 0.011)
	_geo.sign("COLEÇÃO", Vector3(0, 3.44, -12.19), 0.006, PAPER)
	_garage_workshop()
	_omni(Vector3(-6.9, 3.75, 3.7), Color("#ffddae"), 1.77, 11.0)
	_omni(Vector3(6.2, 3.78, 2.1), Color("#d4fff7"), 1.45, 10.5)
	_omni(Vector3(-1.2, 3.9, -7.55), Color("#f3ebd0"), 1.42, 11.0)
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


func _garage_annex(rows: int) -> void:
	var length := float(rows) * 7.65 + 5.0
	var center := -12.5 - length * 0.5
	_geo.surface(Vector3(0, 0, center), Vector3(43.6, 0, length), Color("#707876"), "slab", 4.6)
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
	_geo.beveled(Vector3(-10.98, 1.98, 3.72), Vector3(0.13, 1.45, 4.11), Color("#81796a"))
	_geo.box(Vector3(-10.89, 2.39, 3.72), Vector3(0.04, 0.05, 3.63), STEEL_DARK)
	for i in 5:
		var z := 2.42 + float(i) * 0.57
		var length := 0.29 + float(i) * 0.057
		_geo.beveled(Vector3(-10.86, 2.27 - length * 0.5, z), Vector3(0.041, length, 0.061), Color("#b2b2a2"))
		_geo.beveled(Vector3(-10.85, 2.27, z), Vector3(0.054, 0.083, 0.121), STEEL)
	_geo.box(Vector3(-10.78, 2.72, 3.69), Vector3(0.29, 0.091, 3.39), STEEL)
	_geo.light_strip(Vector3(-10.72, 2.661, 3.69), Vector3(0.16, 0.028, 3.14), Color("#fff0c8"))
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
			var swatch := Vector3(9.13, 1.26 + float(row) * 0.35, -0.84 + float(col) * 0.47)
			_geo.beveled(swatch + Vector3(0.02, 0, 0), Vector3(0.08, 0.286, 0.365), STEEL_DARK)
			_geo.beveled(swatch - Vector3(0.026, 0, 0), Vector3(0.067, 0.24, 0.319), tint)
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
			_geo.beveled(Vector3(-10.18, level + 0.23, -5.99 + float(crate) * 0.91), Vector3(0.39, 0.38, 0.72), tint)
	_terminal(Vector3(-8.68, 0, -8.6), 0.34, "QUADRO DE METAS", BLUE)
	_target("goals", "", "Quadro de metas", "Consultar metas", Vector3(-8.48, 0.9, -8.02), 2.20)


func _meet() -> void:
	spawn = Vector3(0, 0.03, 8.3)
	var horizon := Color("#a68a87")
	_atmosphere(Color("#274767"), horizon, Color("#ffd2a6"), 0.83, 0.68, 0.0039, Vector3(-13, 157, 0), 0.57, Color("#a2b3c6"))
	_geo.surface(Vector3(0, 0, -5.0), Vector3(54, 0, 39), Color("#5a6269"), "asphalt", 4.5)
	var water := Style.water(Vector2(420, 340), Color("#263f56"), Color("#887f9d"), horizon, 139.0)
	water.position = Vector3(0, -0.81, -192.0)
	_geo.add_child(water)
	_geo.box(Vector3(0, -0.6, -24.2), Vector3(54, 1.1, 0.50), Color("#50545d"))
	_fence(Vector3(0, 0, -24.15), 54.0)
	for x in [-26.85, 26.85]:
		_geo.box(Vector3(x, 0.69, -5.0), Vector3(0.23, 1.38, 39), Color("#32454f"), true)
	_geo.box(Vector3(0, 0.62, 14.35), Vector3(54, 1.25, 0.28), STEEL_DARK, true)
	for x in [-20.5, -11.9, 10.9, 20.4]:
		_container(Vector3(x, 0.0, -20.8), 5.9, Color("#895448") if x < 0 else Color("#4c6877"))
	_container(Vector3(-20.5, 2.42, -20.8), 5.9, Color("#635460"))
	_container(Vector3(20.4, 2.42, -20.8), 5.9, Color("#72746d"))
	for x in [-23.7, -10.0, 10.0, 23.7]:
		_lamp(Vector3(x, 0, -6.48), AMBER, 4.85)
		if absf(x) < 12.0:
			_omni(Vector3(x, 4.40, -5.83), Color("#ffc789"), 2.05, 11.0)
	for x in [-9.7, 9.7]:
		_lamp(Vector3(x, 0, 5.85), AMBER, 4.65)
		_omni(Vector3(x, 4.25, 3.75), Color("#ffd394"), 2.25, 12.0)
	_omni(Vector3(0, 4.58, -14.7), Color("#a9c7e5"), 1.25, 13.0)
	for x in [-12.4, 12.4]:
		_crane(Vector3(x, -0.75, -30.0), x < 0)
		_hill(Vector3(x * 3.4, -1.2, -83), 25.0, 9.0, Color("#62677b"))
	_hill(Vector3(-10.0, -2.6, -117), 43.0, 16.0, Color("#767688"))
	_geo.beveled(Vector3(0, 2.8, -17.45), Vector3(10.7, 0.91, 0.26), Color("#343f48"))
	for x in [-5.2, 5.2]:
		_geo.box(Vector3(x, 1.18, -17.45), Vector3(0.16, 2.42, 0.22), STEEL_DARK, true)
		_geo.light_strip(Vector3(x, 2.78, -17.30), Vector3(0.09, 0.50, 0.05), AMBER)
	_geo.sign("PORTO DA VIGÍLIA", Vector3(0, 2.87, -17.29), 0.0144, PAPER)
	_geo.sign("PONTO DE ENCONTRO", Vector3(0, 2.57, -17.29), 0.0053, AMBER)
	_counter(Vector3(-9.3, 0, 8.8), 3.4, 0.2, AMBER)
	_geo.beveled(Vector3(-9.25, 2.54, 7.95), Vector3(4.0, 0.22, 2.6), Color("#905744"))
	for x in [-11.09, -7.41]:
		_geo.box(Vector3(x, 1.22, 7.05), Vector3(0.12, 2.43, 0.14), STEEL)
	_geo.light_strip(Vector3(-9.25, 2.42, 8.83), Vector3(2.64, 0.058, 0.09), Color("#f8ce98"))
	for x in [-20.8, -17.9, -14.9]:
		_geo.cylinder(Vector3(x, 0.35, 7.15), 0.33, 0.70, Color("#8a6154"))
		for level in [0.095, 0.33, 0.57]:
			_geo.cylinder(Vector3(x, level, 7.15), 0.346, 0.040, Color("#544b4b"))
		_geo.cylinder(Vector3(x, 0.71, 7.15), 0.375, 0.065, Color("#bd9a75"))
		_geo.beveled(Vector3(x + 0.81, 0.23, 7.10), Vector3(0.40, 0.46, 0.43), STEEL_DARK, true)
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
	_atmosphere(Color("#5385a5"), Color("#cbd9d6"), Color("#fff0d9"), 0.66, 1.07, 0.0020, Vector3(-38, -26, 0), 0.69)
	_geo.surface(Vector3(0, 0, -4.0), Vector3(44, 0, 36), Color("#7a807c"), "concrete")
	for side in [-1.0, 1.0]:
		_geo.box(Vector3(side * 2.02, 0.012, -4.5), Vector3(0.045, 0.01, 28.6), PAPER.darkened(0.18))
	_fence(Vector3(0, 0, -21.6), 44.0)
	_geo.box(Vector3(0, 0.64, 13.9), Vector3(44, 1.28, 0.25), STEEL_DARK, true)
	for x in [-21.9, 21.9]:
		_geo.box(Vector3(x, 0.64, -4), Vector3(0.24, 1.28, 36), STEEL_DARK, true)
		_geo.box(Vector3(x, 0.68, -4), Vector3(0.27, 0.22, 36), LIME.darkened(0.13))
	_geo.surface(Vector3(0, -0.08, -34.0), Vector3(84, 0, 24), Color("#6c7c66"), "earth", 5.5, false)
	_geo.box(Vector3(0, -0.03, -27.0), Vector3(84, 0.04, 5.8), Color("#343c43"))
	for x in range(-36, 39, 4):
		_geo.box(Vector3(x, 0.008, -27.0), Vector3(2.1, 0.01, 0.08), PAPER)
	_grandstand(Vector3(-5.0, 0.13, -40.0))
	_hill(Vector3(45, -0.6, -71), 34.0, 15.0, Color("#6c8a76"))
	_hill(Vector3(-43, -1.2, -78), 32.0, 19.0, Color("#748d7f"))
	_hill(Vector3(10, -1.2, -117), 54.0, 23.0, Color("#849d94"))
	_geo.beveled(Vector3(0, 3.04, -16.75), Vector3(18.0, 0.97, 0.34), Color("#2d4756"))
	for x in [-8.65, 8.65]:
		_geo.box(Vector3(x, 1.32, -16.75), Vector3(0.23, 2.66, 0.31), Color("#6e9ea4"), true)
		_geo.beveled(Vector3(x, 0.14, -16.75), Vector3(0.50, 0.28, 0.55), STEEL_DARK)
	for x in [-7.9, 7.9]:
		for i in 3:
			for j in 2:
				if (i + j) % 2 == 0:
					_geo.box(Vector3(x + 0.20 * (float(i) - 1.0), 2.91 + float(j) * 0.22, -16.57), Vector3(0.20, 0.22, 0.02), LIME)
	_geo.sign("PADDOCK CANDEIA", Vector3(0, 3.14, -16.53), 0.0145, PAPER)
	_geo.sign("CENTRO DE COMPETIÇÕES", Vector3(0, 2.69, -16.53), 0.0058, LIME)
	_pit_shelter(Vector3(-17.30, 0, -9.8), "OFICIAIS", BLUE)
	_pit_shelter(Vector3(16.9, 0, -10.4), "PREPARAÇÃO", Color("#7c9381"))

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
	_atmosphere(Color("#577c99"), Color("#e3c5a5"), Color("#ffe1bc"), 0.77, 0.96, 0.0025, Vector3(-27, -58, 0), 0.55)
	_geo.surface(Vector3(0, 0, -3.0), Vector3(48, 0, 37), Color("#717a77"), "asphalt", 4.8)
	_geo.surface(Vector3(0, 0.007, -11.61), Vector3(44, 0, 16.86), Color("#8a9287"), "slab", 5.5, false)
	_room_wall(Vector3(0, 2.65, -20.2), Vector3(48, 5.3, 0.27), Color("#657e82"), AMBER.darkened(0.12))
	_geo.box(Vector3(0, 5.12, -11.7), Vector3(45, 0.38, 16.95), STEEL_DARK, true)
	_geo.beveled(Vector3(0, 4.76, -3.26), Vector3(45, 0.83, 0.31), Color("#435864"))
	_geo.sign("REVENDA DO CAIS", Vector3(0, 4.78, -3.08), 0.018, PAPER)
	_geo.light_strip(Vector3(0, 4.35, -3.10), Vector3(43.5, 0.037, 0.054), Color("#eec799"))
	_omni(Vector3(-4.2, 4.1, -7.8), Color("#bfeff1"), 1.27, 15.0)
	_omni(Vector3(4.2, 4.1, -7.8), Color("#ffe2c2"), 1.27, 15.0)
	_geo.box(Vector3(0, 0.59, 15.28), Vector3(48, 1.18, 0.3), STEEL_DARK, true)
	for side in [-1.0, 1.0]:
		_geo.box(Vector3(side * 23.87, 0.61, -3.0), Vector3(0.25, 1.22, 37), STEEL_DARK, true)
		for z in [-4.0, -10.8, -17.7]:
			_geo.box(Vector3(side * 21.9, 2.50, z), Vector3(0.27, 5.0, 0.38), Color("#516c72"), true)
			_geo.box(Vector3(side * 21.9, 0.47, z), Vector3(0.36, 0.94, 0.48), AMBER.darkened(0.1))
		var x: float = side * 21.92
		_geo.box(Vector3(x, 1.70, -10.9), Vector3(0.14, 0.15, 13.95), STEEL)
		for z in [-7.37, -14.20]:
			var glass_at := Vector3(x, 2.96, z)
			_geo.glass(glass_at, Vector3(6.64, 2.45, 0), Color(0.51, 0.66, 0.71, 0.24), PI * 0.5)
			_geo.box(glass_at + Vector3(0, -1.29, 0), Vector3(0.11, 0.12, 6.64), STEEL)
			_geo.box(glass_at, Vector3(0.11, 2.59, 0.085), STEEL)
	for z in [-4.3, -9.8, -15.3]:
		_geo.box(Vector3(0, 4.855, z), Vector3(44.3, 0.16, 0.27), Color("#435a5e"))
		for x in [-17.2, -8.6, 0.0, 8.6, 17.2]:
			_geo.beveled(Vector3(x, 4.729, z), Vector3(4.72, 0.105, 0.36), Color("#768482"))
			_geo.light_strip(Vector3(x, 4.666, z), Vector3(4.55, 0.033, 0.23), Color("#eef3e1"))
	for x in range(-20, 21, 5):
		var window := Vector3(x, 2.97, -19.97)
		_geo.box(window, Vector3(4.54, 1.78, 0.13), Color("#3e5863"))
		_geo.box(window + Vector3(0, 0, 0.075), Vector3(4.29, 1.58, 0.04), Color("#7d9da4"))
		_geo.box(window + Vector3(0, -0.57, 0.103), Vector3(4.28, 0.45, 0.021), Color("#6d898d"))
		for separator in [-1.36, 1.36]:
			_geo.box(window + Vector3(separator, 0, 0.121), Vector3(0.062, 1.58, 0.039), Color("#b8c5be"))
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
		_geo.beveled(at + Vector3(0, -0.009, 0), Vector3(3.36, 0.050, 5.34), Color("#9a9d91"))
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
	var shadow := Style.shadow(dimensions.x * 1.49, dimensions.z * 1.27, 0.63, true)
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
	tag.outline_size = 6
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
	label.outline_size = 6
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
	var shade := Style.shadow(2.80, 1.43, 0.56, true)
	shade.position = at + Vector3(0.02, 0.021, 0.04)
	shade.rotation.y = yaw
	_geo.add_child(shade)
	_geo.beveled(at + Vector3.UP * 0.102, Vector3(2.18, 0.20, 0.92), STEEL_DARK, true, yaw)
	_geo.beveled(at + Vector3.UP * 0.61, Vector3(0.52, 0.99, 0.54), Color("#657679"), true, yaw)
	_geo.beveled(at + Vector3.UP * 1.34, Vector3(2.25, 0.71, 0.19), Color("#526269"), true, yaw)
	_geo.box(at + orient * Vector3(0.0, 1.34, 0.099), Vector3(2.05, 0.58, 0.019), Color("#26353c"), false, yaw)
	_geo.light_strip(at + orient * Vector3(-0.971, 1.34, 0.112), Vector3(0.035, 0.46, 0.014), ink, yaw)
	var title_width := Ui.DISPLAY.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 58).x
	_geo.sign(title, at + orient * Vector3(0.031, 1.44, 0.115), minf(0.0070, 1.87 / maxf(1.0, title_width)), PAPER, yaw)
	if not subtitle.is_empty() or reward > 0.0:
		var detail := subtitle if reward <= 0.0 else "%s · %s" % [subtitle, Ui.money(int(reward))]
		var detail_width := Ui.DISPLAY.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 58).x
		_geo.sign(detail, at + orient * Vector3(0.034, 1.17, 0.115), minf(0.0043, 1.87 / maxf(1.0, detail_width)), ink, yaw)


func _event_mode(event: Dictionary) -> String:
	match str(event.mode):
		"sprint": return "SPRINT"
		"drag": return "ARRANCADA"
		"time_trial": return "TEMPO"
	return "CIRCUITO"


func _pit_shelter(at: Vector3, plaque: String, ink: Color) -> void:
	_geo.box(at + Vector3(0, 1.43, -2.05), Vector3(6.3, 2.86, 0.31), Color("#657579"), true)
	_geo.beveled(at + Vector3(0, 2.89, 0), Vector3(6.55, 0.26, 4.36), STEEL_DARK)
	for side in [-1.0, 1.0]:
		_geo.box(at + Vector3(side * 3.04, 1.43, 1.97), Vector3(0.24, 2.86, 0.25), Color("#465762"), true)
		_geo.beam(at + Vector3(side * 3.04, 2.15, 1.97), at + Vector3(side * 3.04, 2.79, 0.72), 0.09, 0.11, STEEL)
		_geo.box(at + Vector3(side * 3.03, 0.19, 1.96), Vector3(0.272, 0.38, 0.275), ink)
	_geo.box(at + Vector3(0, 2.84, 2.18), Vector3(6.58, 0.34, 0.13), Color("#3b515b"))
	_geo.sign(plaque, at + Vector3(0, 2.83, 2.255), 0.0074, PAPER)
	_geo.light_strip(at + Vector3(0, 2.71, 0.75), Vector3(4.19, 0.07, 0.17), PAPER)
	_counter(at + Vector3(0, 0, -0.45), 3.55, 0, ink)


func _counter(at: Vector3, span: float, yaw: float, ink: Color) -> void:
	var orient := Basis(Vector3.UP, yaw)
	_geo.box(at + Vector3.UP * 0.46, Vector3(span, 0.89, 0.62), Color("#3b494a"), true, yaw)
	_geo.beveled(at + Vector3.UP * 0.924, Vector3(span + 0.17, 0.104, 0.74), Color("#a09985"), true, yaw)
	_geo.box(at + orient * Vector3(0, 0.83, 0.322), Vector3(span * 0.96, 0.027, 0.012), ink, false, yaw)
	for i in 3:
		var level := 0.25 + float(i) * 0.17
		_geo.beveled(at + orient * Vector3(-span * 0.24, level, 0.325), Vector3(span * 0.44, 0.146, 0.049), STEEL, false, yaw)
		_geo.box(at + orient * Vector3(-span * 0.24, level + 0.031, 0.355), Vector3(span * 0.13, 0.018, 0.021), Color("#86918e"), false, yaw)
	_geo.beveled(at + orient * Vector3(span * 0.22, 1.014, 0.015), Vector3(0.34, 0.08, 0.25), ink.darkened(0.36), false, yaw)


func _room_wall(at: Vector3, dimensions: Vector3, tint: Color, stripe: Color) -> void:
	_geo.box(at, dimensions, tint, true)
	_geo.box(Vector3(at.x, 0.60, at.z), Vector3(dimensions.x + 0.025, 1.2, dimensions.z + 0.025), STEEL_DARK)
	_geo.box(Vector3(at.x, 1.25, at.z), Vector3(dimensions.x + 0.044, 0.055, dimensions.z + 0.044), stripe)


func _wall_sign(words: String, at: Vector3, width: float, ink: Color, scale: float, yaw := 0.0) -> void:
	var back := Vector3(0, 0, -0.075).rotated(Vector3.UP, yaw)
	_geo.beveled(at + back, Vector3(width, 0.66, 0.13), STEEL_DARK, false, yaw)
	_geo.sign(words, at, scale, ink, yaw)


func _fence(at: Vector3, width: float) -> void:
	_geo.box(at + Vector3.UP * 0.53, Vector3(width, 1.06, 0.25), Color("#394951"), true)
	for y in [0.22, 0.60, 1.02]:
		_geo.box(at + Vector3(0, y, 0.145), Vector3(width, 0.066, 0.045), Color("#697572"))
	for post in ceili(width / 3.0):
		var x := -width * 0.5 + float(post) * 3.0 + 1.35
		_geo.box(at + Vector3(x, 0.66, 0.19), Vector3(0.10, 1.32, 0.13), AMBER.darkened(0.19))


func _container(at: Vector3, width: float, tint: Color) -> void:
	_geo.beveled(at + Vector3.UP * 1.21, Vector3(width, 2.42, 2.26), tint.darkened(0.16), true)
	_geo.box(at + Vector3(0, 1.21, 1.127), Vector3(width - 0.16, 2.17, 0.035), tint.darkened(0.08))
	var ribs := roundi(width / 0.27)
	for i in ribs:
		var x := (float(i) + 0.5) / float(ribs) * (width - 0.36) - (width - 0.36) * 0.5
		_geo.beveled(at + Vector3(x, 1.21, 1.151), Vector3(0.085, 2.08, 0.067), tint)
	for y in [0.103, 2.317]:
		_geo.box(at + Vector3(0, y, 1.133), Vector3(width, 0.156, 0.097), tint.darkened(0.23))
		for side in [-1.0, 1.0]:
			_geo.box(at + Vector3(side * (width * 0.5 - 0.07), y, 1.14), Vector3(0.143, 0.168, 0.111), tint.lightened(0.16))


func _tires(at: Vector3, height: int) -> void:
	for i in height:
		_geo.tire(at + Vector3.UP * (0.12 + float(i) * 0.222), Color("#303539").lightened(float(i % 2) * 0.035))


func _lamp(at: Vector3, ink: Color, height: float) -> void:
	_geo.box(at + Vector3.UP * (height * 0.48), Vector3(0.105, height * 0.96, 0.108), STEEL, true)
	_geo.beveled(at + Vector3.UP * 0.17, Vector3(0.28, 0.34, 0.28), STEEL_DARK)
	_geo.beam(at + Vector3(0, height - 0.49, 0), at + Vector3(0, height - 0.10, 0.55), 0.085, 0.083, STEEL)
	_geo.beveled(at + Vector3(0, height - 0.12, 0.63), Vector3(0.32, 0.15, 0.53), STEEL_DARK)
	_geo.light_strip(at + Vector3(0, height - 0.203, 0.65), Vector3(0.246, 0.027, 0.36), ink.lightened(0.21))


func _bollards(at: Vector3, count: int, ink: Color) -> void:
	for i in count:
		var post := at + Vector3(1.27 * float(i), 0.44, 0)
		_geo.beveled(post, Vector3(0.25, 0.88, 0.25), STEEL, true)
		_geo.box(post + Vector3.UP * 0.34, Vector3(0.267, 0.13, 0.267), ink)


func _crane(at: Vector3, mirror: bool) -> void:
	var sign_x := -1.0 if mirror else 1.0
	var paint := Color("#5b555d")
	for x in [-3.25, 3.25]:
		_geo.box(at + Vector3(x, 4.34, 0), Vector3(0.46, 8.68, 0.54), paint)
		_geo.beam(at + Vector3(x * 1.22, 0, -3.8), at + Vector3(x, 7.4, 0), 0.36, 0.41, paint.darkened(0.16))
	_geo.box(at + Vector3(sign_x * 2.0, 8.73, 0.0), Vector3(17.1, 0.25, 0.49), paint)
	_geo.box(at + Vector3(sign_x * 2.0, 9.87, 0.0), Vector3(17.1, 0.23, 0.39), paint)
	for i in 8:
		var x := sign_x * (2.0 - 8.55 + float(i) * 2.1375)
		var next := x + sign_x * 2.1375
		_geo.beam(at + Vector3(x, 8.76, 0), at + Vector3((x + next) * 0.5, 9.83, 0), 0.14, 0.22, paint)
		_geo.beam(at + Vector3((x + next) * 0.5, 9.83, 0), at + Vector3(next, 8.76, 0), 0.14, 0.22, paint)
	_geo.beveled(at + Vector3(-sign_x * 3.12, 8.18, 0.64), Vector3(1.26, 1.08, 1.32), paint.lightened(0.13))
	_geo.box(at + Vector3(-sign_x * 3.12, 8.32, 1.275), Vector3(0.96, 0.45, 0.056), Color("#50606a"))
	_geo.box(at + Vector3(sign_x * 8.65, 7.2, 0.0), Vector3(0.070, 3.5, 0.065), paint.darkened(0.4))
	_geo.beveled(at + Vector3(sign_x * 8.65, 5.40, 0.0), Vector3(0.37, 0.25, 0.35), paint)
	_geo.light_strip(at + Vector3(sign_x * 10.39, 9.97, 0), Vector3(0.13, 0.17, 0.13), Color("#eb8d6f"))


func _grandstand(at: Vector3) -> void:
	for row in 6:
		var y := 0.63 + float(row) * 0.43
		var z := -float(row) * 0.92
		_geo.box(at + Vector3(0, y * 0.5, z), Vector3(40.0, y, 1.03), Color("#687472"))
		for x in range(-19, 20):
			if x in [-7, 7]:
				continue
			var color := Color("#527784") if absi(x) < 7 else Color("#8b9f96")
			_geo.beveled(at + Vector3(x, y + 0.18, z + 0.08), Vector3(0.86, 0.29, 0.38), color.lightened(float(row % 2) * 0.075))
	_geo.box(at + Vector3(0, 5.70, -3.15), Vector3(42.5, 0.22, 6.1), Color("#657a7c"))
	for x in [-20.2, -6.8, 6.8, 20.2]:
		_geo.box(at + Vector3(x, 2.85, -5.75), Vector3(0.24, 5.7, 0.22), STEEL_DARK)
		_geo.beam(at + Vector3(x, 4.05, -5.75), at + Vector3(x, 5.61, -0.54), 0.12, 0.17, STEEL)


func _hill(at: Vector3, radius: float, height: float, tint: Color) -> void:
	if _ridge_mesh == null:
		_ridge_mesh = Forms.loft([
			Vector4(0.48, -0.50, 0.48, 0), Vector4(0.48, -0.14, 0.44, -0.01),
			Vector4(0.33, 0.18, 0.31, -0.026), Vector4(0.19, 0.39, 0.17, -0.050),
			Vector4(0.032, 0.50, 0.04, -0.060),
		], 9, PI * 0.09)
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 1.0
	var mound := MeshInstance3D.new()
	mound.mesh = _ridge_mesh
	mound.material_override = material
	mound.position = at
	mound.scale = Vector3(radius * 2.0, height, radius * 1.52)
	mound.rotation.y = at.x * 0.021
	mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geo.add_child(mound)


func _omni(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var fill := OmniLight3D.new()
	fill.position = at
	fill.light_color = color
	fill.light_energy = energy
	fill.omni_range = reach
	fill.omni_attenuation = 1.0
	add_child(fill)


func _atmosphere(top: Color, horizon: Color, sun_color: Color, ambient: float, sun: float, fog: float,
		angle: Vector3, clouds: float, fill_color := Color.TRANSPARENT) -> void:
	var directional := DirectionalLight3D.new()
	directional.rotation_degrees = angle
	directional.light_color = sun_color
	directional.light_energy = sun
	add_child(directional)
	var lighting := Environment.new()
	lighting.background_mode = Environment.BG_COLOR
	lighting.background_color = top
	if clouds > 0.0:
		add_child(Style.sky(top, horizon, top.darkened(0.21), sun_color, directional.basis.z, clouds))
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	lighting.ambient_light_color = horizon.lerp(Color("#d5e1e1"), 0.66) if fill_color.a == 0.0 else fill_color
	lighting.ambient_light_energy = ambient
	lighting.fog_enabled = fog > 0.0
	lighting.fog_light_color = horizon.lerp(top, 0.37)
	lighting.fog_density = fog
	var environment := WorldEnvironment.new()
	environment.environment = lighting
	add_child(environment)
