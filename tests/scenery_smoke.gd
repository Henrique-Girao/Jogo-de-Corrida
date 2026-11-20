extends SceneTree
## Verifies the rendered pavement and signs using the same meshes as the game.

const Track = preload("res://src/tracks/track.gd")
const Race = preload("res://src/race/race_session.gd")
const Sector = preload("res://src/world/sector.gd")
const Catalog = preload("res://src/domain/catalog.gd")

class SurfaceIndex:
	const UNIT := 16.0
	var cells: Dictionary[Vector2i, PackedVector3Array] = {}

	func _cell(point: Vector3) -> Vector2i:
		return Vector2i(floori(point.x / UNIT), floori(point.z / UNIT))

	func add(instance: MeshInstance3D) -> void:
		var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in range(0, vertices.size(), 3):
			var a := instance.transform * vertices[i]
			var b := instance.transform * vertices[i + 1]
			var c := instance.transform * vertices[i + 2]
			var low := _cell(a.min(b).min(c))
			var high := _cell(a.max(b).max(c))
			for z in range(low.y, high.y + 1):
				for x in range(low.x, high.x + 1):
					var key := Vector2i(x, z)
					var faces: PackedVector3Array = cells.get(key, PackedVector3Array())
					faces.append(a)
					faces.append(b)
					faces.append(c)
					cells[key] = faces

	func below(point: Vector3) -> float:
		var key := _cell(point)
		if not cells.has(key):
			return -INF
		var faces := cells[key]
		var height := -INF
		var from := point + Vector3.UP * 120.0
		for i in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, faces[i], faces[i + 1], faces[i + 2])
			if hit is Vector3:
				height = maxf(height, hit.y)
		return height


var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for id in ["autodromo", "docas", "serra"]:
		_route(id, "circuit", true)
	_route("docas", "sprint", false)
	_route("docas", "drag", false)
	_route("serra", "time_trial", false)
	_lap_line()
	await _signs()
	if _failures == 0:
		print("SCENERY SMOKE OK | piso contínuo, grid, faixa de volta e textos das placas")
	quit(1 if _failures else 0)


func _route(id: String, mode: String, closed: bool) -> void:
	var route := Track.new()
	root.add_child(route)
	route.build(id, mode, 0, 1 if mode == "time_trial" else 6)
	var name := "%s / %s" % [id, mode]
	var points := route.centerline()
	var outline := route.course_outline()
	_expect(route.closed == closed, name + " · topologia")
	_expect((points[0] == points[-1]) == closed, name + " · emenda geométrica")
	_expect((outline[0] == outline[-1]) == closed, name + " · minimapa")
	if closed:
		var first := route.pavement_frame(0.0)
		var last := route.pavement_frame(route.length)
		_expect(first.position == last.position and first.right == last.right, name + " · bordas da emenda")
	var visual: Node3D = route._visuals
	var pavement := SurfaceIndex.new()
	pavement.add(visual.get_node("Asfalto"))
	var land := SurfaceIndex.new()
	land.add(visual.get_node("Terreno"))
	land.add(visual.get_node("Taludes"))
	var probes := ceili(route.length / 3.0)
	var clear := true
	for i in range(probes + 1):
		var distance := lerpf(0.03, route.length - 0.03, i / float(probes))
		var frame := route.pavement_frame(distance)
		for fraction: float in [-0.90, 0.0, 0.90]:
			var point: Vector3 = frame.position + frame.right * (fraction * route.half_width)
			var asphalt_y := pavement.below(point)
			if not is_finite(asphalt_y) or land.below(point) > asphalt_y - 0.02:
				_expect(false, "%s · asfalto encoberto ou ausente em %s" % [name, point])
				clear = false
				break
		if not clear:
			break
	var markings := SurfaceIndex.new()
	markings.add(visual.get_node("Marcas de largada"))
	for i in route.grid_size:
		var slot := route.starting_slot(i, route.grid_size)
		var front := slot.x + route.GRID_FRONT
		_expect(front < route.start_line, name + " · carro atrás da faixa")
		_expect(is_finite(markings.below(_on_road(route, front - 0.065, slot.y))), name + " · travessa à frente")
		var rail := slot.y - route.GRID_HALF_WIDTH + 0.055
		_expect(is_finite(markings.below(_on_road(route, front - 0.65, rail))), name + " · lateral para trás")
		_expect(not is_finite(markings.below(_on_road(route, front + 0.21, rail))), name + " · grid livre à frente")
		_expect(not is_finite(markings.below(_on_road(route, front - 0.65, slot.y))), name + " · grid aberto atrás")
	_check_labels(visual)
	route.free()


func _on_road(route: Track, distance: float, lateral: float) -> Vector3:
	var frame := route.pavement_frame(distance)
	return frame.position + frame.right * lateral


func _lap_line() -> void:
	var race := Race.new()
	race.configure(Catalog.event("copa_apice"), Catalog.vehicle("vetra_x"), [], {"quality": "low"})
	root.add_child(race)
	race.set_physics_process(false)
	var route: Track = race._track
	var car := race._player
	race._elapsed = 48.0
	car.progress_distance = route.length + route.start_line - 0.10
	race.register_laps(car)
	_expect(car.splits == 0, "A emenda continua na mesma volta até a faixa pintada")
	car.progress_distance += 0.20
	race.register_laps(car)
	_expect(car.splits == 1, "A passagem pela faixa registra a volta")
	race._elapsed = 96.0
	car.progress_distance = route.race_finish(2) - 0.15
	race.register_laps(car)
	_expect(car.finish_time < 0.0, "A prova segue até cruzar a faixa")
	car.progress_distance += 0.30
	race.register_laps(car)
	_expect(is_equal_approx(car.finish_time, 96.0), "A faixa registra a chegada da segunda volta")
	race.free()


func _signs() -> void:
	var data := OS.get_environment("XDG_DATA_HOME").simplify_path().trim_suffix("/")
	if data.is_empty() or not OS.get_user_data_dir().begins_with(data + "/"):
		_expect(false, "Use XDG_DATA_HOME temporário para revisar os setores")
		return
	var state := root.get_node("GameState")
	state.money = 300000
	state.reputation = 150
	for id in ["linha_rs", "vetra_x", "iris_22", "fenda_30", "alvor_72", "vektor_v8"]:
		state.purchase("dealer:" + id)
	for id in ["garage", "meet", "official", "market"]:
		var stage := Sector.new()
		root.add_child(stage)
		stage.build(id, state)
		await process_frame
		_check_labels(stage)
		stage.free()


func _check_labels(stage: Node3D) -> void:
	for node in stage.find_children("*", "Label3D", true, false):
		var label := node as Label3D
		if label.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
			continue
		var box := label.get_aabb().size
		var area: Vector2 = label.get_meta("letter_area")
		_expect(box.x <= area.x + 0.014 and box.y <= area.y + 0.014, "Margem da placa · " + label.text)
		_expect(not label.double_sided, "A face traseira não espelha a placa · " + label.text)


func _expect(ok: bool, description: String) -> void:
	if not ok:
		_failures += 1
		push_error(description)
