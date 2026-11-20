extends Node3D
## Procedural meshes and scenery batches. Props share a small set of instanced meshes.

const Style = preload("res://src/art/scene_style.gd")
const CarArt = preload("res://src/art/car_art.gd")
const Models = preload("res://src/art/model_library.gd")
const Forms = preload("res://src/art/mesh_forms.gd")
const Placard = preload("res://src/art/placard.gd")
const WHITE := Color("#eee8d7")
const ORANGE := Color("#dc8c55")
const CYAN := Color("#86bcb5")
const DIRECTIONS := Color("#203c42")
const PROP_CELL := 144.0
const BANK_CELL := 12.0

class Surface:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color, normal := Vector3.UP) -> void:
		vertices.append(a)
		vertices.append(b)
		vertices.append(c)
		for i in 3:
			normals.append(normal)
			colors.append(color)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, normal := Vector3.UP) -> void:
		triangle(a, b, c, color, normal)
		triangle(a, c, d, color, normal)

	func make_mesh(roughness: float, finish_name: String, tile: float) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = roughness
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if not finish_name.is_empty():
			var texcoords := PackedVector2Array()
			texcoords.resize(vertices.size())
			for i in vertices.size():
				texcoords[i] = Vector2(vertices[i].x, vertices[i].z) / tile
			arrays[Mesh.ARRAY_TEX_UV] = texcoords
			material.albedo_texture = Style.pavement(finish_name)
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		return mesh

var _track: Node3D
var _config: Dictionary
var _quality := 1
var _rng := RandomNumberGenerator.new()
var _batches: Dictionary
var _stations := PackedFloat64Array()
var _centerline := PackedVector2Array()
var _ground_bounds: Rect2
var _ground_cells: Vector2i
var _ground_heights := PackedFloat32Array()
var _banks: Dictionary[Vector2i, PackedVector3Array] = {}
var _sites: Array[Rect2] = []


func build(track: Node3D, config: Dictionary) -> void:
	_track = track
	_config = config
	_quality = track.quality
	_rng.seed = track.track_id.hash()
	for point: Vector3 in _track.centerline():
		_centerline.append(Vector2(point.x, point.z))
	_sky()
	_ground()
	_road()
	_start_and_finish()
	match track.track_id:
		"docas":
			_docks()
		"serra":
			_mountains()
		_:
			_speedway()
	_flush_batches()
	_banks.clear()
	_ground_heights.clear()
	_sites.clear()
	_centerline.clear()


func _sky() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = _config.sun_angle
	light.light_color = _config.sun
	light.light_energy = _config.sun_energy
	light.shadow_enabled = _quality == 2
	light.directional_shadow_max_distance = 80.0
	add_child(light)
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = _config.sky_horizon
	add_child(Style.sky(_config.sky_top, _config.sky_horizon, _config.sky_bottom, _config.sun,
		light.basis.z, _config.clouds))
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	settings.ambient_light_color = _config.ambient
	settings.ambient_light_energy = _config.ambient_energy
	settings.fog_enabled = _quality > 0
	settings.fog_light_color = _config.fog
	settings.fog_density = _config.fog_density
	var world := WorldEnvironment.new()
	world.environment = settings
	add_child(world)


func _ground() -> void:
	var surface := Surface.new()
	var bounds: Rect2 = _track.bounds()
	var x0 := bounds.position.x - 225.0
	var x1 := bounds.end.x + 225.0
	var z0 := -bounds.end.y - 230.0
	var z1 := -bounds.position.y + 230.0
	var mountain: bool = _track.track_id == "serra" and _track.mode != "drag"
	var docks: bool = _track.track_id == "docas"
	if docks:
		x0 = -26.0
		var water := Style.water(Vector2(656.0, z1 - z0 + 380.0), Color("#223944"), Color("#736f8a"), _config.sky_horizon, 380.0)
		water.position = Vector3(x0 - 328.0, -1.10, (z0 + z1) * 0.5)
		add_child(water)
		_box(Vector3(x0 + 0.10, -0.23, (z0 + z1) * 0.5), Vector3(0.83, 1.4, z1 - z0), Color("#4b535c"))
		for i in 30:
			var z := z0 + i * (z1 - z0) / 30.0
			_box(Vector3(x0 + 0.68, 0.48, z), Vector3(0.85, 0.76, (z1 - z0) / 30.0 - 0.35), Color("#52606a"))
	var step := 30.0 if not mountain else (15.0 if _quality == 0 else 12.0)
	var dx := ceili((x1 - x0) / step)
	var dz := ceili((z1 - z0) / step)
	_ground_bounds = Rect2(x0, z0, x1 - x0, z1 - z0)
	_ground_cells = Vector2i(dx, dz)
	_ground_heights.resize((dx + 1) * (dz + 1))
	var coarse_line := PackedVector3Array()
	if mountain:
		for index in range(ceili(_track.length / 15.0) + 1):
			coarse_line.append(_track.sample(index * 15.0).position)
	var grid := PackedVector3Array()
	grid.resize((dx + 1) * (dz + 1))
	var ground_y := 0.43 if docks else -0.15
	for row in range(dz + 1):
		for column in range(dx + 1):
			var point_x := lerpf(x0, x1, column / float(dx))
			var point_z := lerpf(z0, z1, row / float(dz))
			var elevation := _ridge_height(point_x, point_z, coarse_line) if mountain else ground_y
			grid[row * (dx + 1) + column] = Vector3(point_x, elevation, point_z)
			_ground_heights[row * (dx + 1) + column] = elevation
	for row in dz:
		for column in dx:
			var i := row * (dx + 1) + column
			var a := grid[i]
			var b := grid[i + 1]
			var c := grid[i + dx + 2]
			var d := grid[i + dx + 1]
			var shade := clampf(0.50 + 0.29 * sin(column * 0.24 + row * 0.16) + 0.13 * cos(row * 0.19), 0.10, 0.90)
			var base: Color = _config.ground_a.lerp(_config.ground_b, shade)
			surface.triangle(a, b, c, base, (c - a).cross(b - a).normalized())
			surface.triangle(a, c, d, base, (d - a).cross(c - a).normalized())
	_place_surface("Terreno", surface, 1.0, "concrete" if docks else "earth", 10.5)


func _soil_height(point: Vector2) -> float:
	var cell := (point - _ground_bounds.position) / _ground_bounds.size * Vector2(_ground_cells)
	cell = cell.clamp(Vector2.ZERO, Vector2(_ground_cells))
	var col := mini(floori(cell.x), _ground_cells.x - 1)
	var row := mini(floori(cell.y), _ground_cells.y - 1)
	var stride := _ground_cells.x + 1
	var i := row * stride + col
	var x := cell.x - col
	var z := cell.y - row
	var a := _ground_heights[i]
	var b := _ground_heights[i + 1]
	var c := _ground_heights[i + stride + 1]
	var d := _ground_heights[i + stride]
	if x >= z:
		return lerpf(a, b, x) + (c - b) * z
	return lerpf(a, d, z) + (c - d) * x


func _bank_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / BANK_CELL), floori(point.z / BANK_CELL))


func _index_banks(vertices: PackedVector3Array) -> void:
	for i in range(0, vertices.size(), 3):
		var a := vertices[i]
		var b := vertices[i + 1]
		var c := vertices[i + 2]
		var low := _bank_cell(a.min(b).min(c))
		var high := _bank_cell(a.max(b).max(c))
		for row in range(low.y, high.y + 1):
			for col in range(low.x, high.x + 1):
				var cell := Vector2i(col, row)
				var tile: PackedVector3Array = _banks.get(cell, PackedVector3Array())
				tile.append(a)
				tile.append(b)
				tile.append(c)
				_banks[cell] = tile


func _footing(at: Vector3) -> float:
	var floor_y := _soil_height(Vector2(at.x, at.z))
	var cell := _bank_cell(at)
	if not _banks.has(cell):
		return floor_y
	var tile := _banks[cell]
	var from := Vector3(at.x, at.y + 65.0, at.z)
	for i in range(0, tile.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, tile[i], tile[i + 1], tile[i + 2])
		if hit is Vector3:
			floor_y = maxf(floor_y, hit.y)
	return floor_y


func _reserve(at: Vector3, size: Vector2, basis: Basis, gap: float = 1.2) -> bool:
	var center := Vector2(at.x, at.z)
	var axis_x := Vector2(basis.x.x, basis.x.z)
	var axis_z := Vector2(basis.z.x, basis.z.z)
	var span := axis_x.abs() * size.x + axis_z.abs() * size.y
	var area := Rect2(center - span * 0.5, span)
	if not _ground_bounds.encloses(area):
		return false
	var padded := area.grow(gap * 0.5)
	for used in _sites:
		if used.intersects(padded):
			return false
	# The extra two metres cover the space between consecutive centerline samples.
	var corridor: float = _track.half_width + 3.9
	var nearby := area.grow(corridor)
	var limits := size * 0.5 + Vector2.ONE * corridor
	for point in _centerline:
		if nearby.has_point(point):
			var to_road := point - center
			if absf(to_road.dot(axis_x)) <= limits.x and absf(to_road.dot(axis_z)) <= limits.y:
				return false
	_sites.append(padded)
	return true


func _ridge_height(x: float, z: float, coarse_line: PackedVector3Array) -> float:
	var near_squared := INF
	var road_y := 0.0
	for point in coarse_line:
		var squared := (point.x - x) * (point.x - x) + (point.z - z) * (point.z - z)
		if squared < near_squared:
			near_squared = squared
			road_y = point.y
	var distance := sqrt(near_squared)
	var hills := (sin(x * 0.019 + z * 0.003) * 0.58 + sin(z * 0.017 - x * 0.008) * 0.42)
	if distance < 33.0:
		return road_y - 2.1 - distance * 0.065
	var strength := smoothstep(33.0, 138.0, distance)
	return road_y - 4.0 + strength * (hills * 44.0 + 12.0) + sin(x * 0.055 + z * 0.025) * strength * 4.0


func _road() -> void:
	var road := Surface.new()
	var verges := Surface.new()
	var paint := Surface.new()
	var grid := Surface.new()
	var width: float = _track.half_width
	var road_color: Color = _config.road
	var shoulder: Color = _config.shoulder
	var mountain: bool = _track.track_id == "serra" and _track.mode != "drag"
	_stations = _track.stations()
	if not _track.closed:
		_stations.insert(0, -16.0)
		_stations.insert(0, -32.0)
		_stations.append(_track.length + 20.0)
		_stations.append(_track.length + 44.0)
	var divisions := _stations.size() - 1
	var current: Dictionary = _track.pavement_frame(_stations[0])
	for i in divisions:
		var next: Dictionary = _track.pavement_frame(_stations[i + 1])
		var shade := sin(TAU * 7.0 * i / float(divisions)) * 0.018
		_strip(road, current, next, -width, width, 0, 0, road_color.lightened(shade))
		for side in [-1.0, 1.0]:
			_strip(road, current, next, side * width, side * (width + 1.35), 0.0, -0.08, shoulder)
			var verge: Color = _config.ground_a.lerp(_config.ground_b, 0.39)
			if mountain:
				_strip(verges, current, next, side * (width + 1.35), side * (width + 10.0), -0.08, -2.65, verge)
			else:
				_strip(verges, current, next, side * (width + 1.35), side * (width + 4.4), -0.08, -1.28, verge)
			var curb: Color = _config.curb_a if i % 2 == 0 else _config.curb_b
			if _track.mode != "drag" and _track.track_id != "serra":
				_strip(paint, current, next, side * width, side * (width + 0.62), 0.019, 0.008, curb)
			_strip(paint, current, next, side * (width - 0.23), side * (width - 0.07), 0.021, 0.021, _config.stripe)
		current = next
	if _track.mode == "drag":
		_line(paint, -20.0, _track.length + 26.0, -0.09, 0.09, _config.stripe)
	else:
		_midline(paint)
	_grid(grid)
	var finish: float = _track.start_line if _track.closed else _track.length
	_checkered(paint, finish, width)
	if not _track.closed:
		_line(paint, _track.start_line, _track.start_line + 0.22, -width, width, WHITE)
	_place_surface("Asfalto", road, 0.91 if _track.track_id == "docas" else 0.98, "asphalt", 5.7)
	_place_surface("Taludes", verges, 1.0, "concrete" if _track.track_id == "docas" else "earth", 6.2)
	_index_banks(verges.vertices)
	_place_surface("Sinalização horizontal", paint, 0.92)
	_place_surface("Marcas de largada", grid, 0.92)


func _strip(surface: Surface, a: Dictionary, b: Dictionary, left: float, right: float, y_left: float, y_right: float, color: Color) -> void:
	var ap: Vector3 = a.position
	var bp: Vector3 = b.position
	var ar: Vector3 = a.right
	var br: Vector3 = b.right
	var near_left := ap + ar * left + Vector3.UP * y_left
	var near_right := ap + ar * right + Vector3.UP * y_right
	var far_right := bp + br * right + Vector3.UP * y_right
	var far_left := bp + br * left + Vector3.UP * y_left
	var normal := (near_right - near_left).cross(far_left - near_left).normalized()
	if normal.y > 0.0:
		surface.quad(near_left, far_left, far_right, near_right, color, normal)
	else:
		surface.quad(near_left, near_right, far_right, far_left, color, -normal)


func _line(surface: Surface, first: float, last: float, left: float, right: float, color: Color, h := 0.024) -> void:
	if last <= first:
		return
	var previous: Dictionary = _track.pavement_frame(first)
	var index := _stations.bsearch(first, false)
	while index < _stations.size() and _stations[index] < last:
		var next: Dictionary = _track.pavement_frame(_stations[index])
		_strip(surface, previous, next, left, right, h, h, color)
		previous = next
		index += 1
	_strip(surface, previous, _track.pavement_frame(last), left, right, h, h, color)


func _frame(distance: float) -> Dictionary:
	var frame: Dictionary = _track.sample(distance)
	if not _track.closed:
		var over: float = distance - clampf(distance, 0.0, _track.length)
		frame.position += frame.forward * over
	return frame


func _midline(paint: Surface) -> void:
	if _track.track_id == "autodromo":
		return
	for index in ceili(_track.length / 13.0):
		var d := index * 13.0
		var part: Dictionary = _track.sample(d)
		if _track.track_id == "serra" and absf(part.curvature) > 0.012:
			_line(paint, d, minf(d + 13.0, _track.length), -0.22, -0.08, _config.stripe)
			_line(paint, d, minf(d + 13.0, _track.length), 0.08, 0.22, _config.stripe)
		else:
			_line(paint, d, minf(d + 4.4, _track.length), -0.075, 0.075, _config.stripe.darkened(0.14))


func _grid(paint: Surface) -> void:
	var half: float = _track.GRID_HALF_WIDTH
	for i in int(_track.grid_size):
		var slot: Vector2 = _track.starting_slot(i, _track.grid_size)
		var front: float = slot.x + _track.GRID_FRONT
		_line(paint, front - 0.13, front, slot.y - half, slot.y + half, WHITE, 0.030)
		for edge in [slot.y - half, slot.y + half - 0.11]:
			_line(paint, front - 1.02, front - 0.13, edge, edge + 0.11, WHITE, 0.030)
	if _track.mode == "drag":
		var width: float = _track.half_width
		for mark in [100.0, 200.0, 300.0]:
			var d: float = mark + _track.DRAG_GRID
			for side in [-1.0, 1.0]:
				_line(paint, d - 0.10, d + 0.10, side * (width - 0.35), side * (width - 1.90), WHITE)


func _checkered(paint: Surface, d: float, width: float) -> void:
	var n := ceili(width * 2.0 / 0.66)
	for i in n:
		var left := lerpf(-width, width, i / float(n))
		var right := lerpf(-width, width, (i + 1) / float(n))
		for row in 2:
			var first := d - 0.64 + row * 0.64
			var shade := WHITE if (i + row) % 2 == 0 else Color("#222b2e")
			_line(paint, first, first + 0.64, left, right, shade, 0.032)


func _start_and_finish() -> void:
	var heading := str(_track.route_name).to_upper()
	var accent := ORANGE
	match _track.track_id:
		"docas":
			accent = CYAN
		"serra":
			accent = Color("#e7ba7f")
	if _track.mode == "drag":
		heading = "402 M  /  ARRANCADA"
	_gantry(_track.start_line, heading, accent)
	if not _track.closed:
		_gantry(_track.length, "CHEGADA", accent)
		for mark in range(100, int(_track.length), 100):
			if _track.mode == "drag":
				_road_sign(mark + _track.DRAG_GRID, 1.0, str(mark) + " M", accent)
			elif mark % 300 == 0:
				_road_sign(mark, -1.0, "%d M" % mark, accent)


func _gantry(distance: float, title: String, accent: Color) -> void:
	var frame := _frame(distance)
	var width: float = _track.half_width + 3.75
	var upright := _basis(frame)
	var deck: Vector3 = frame.position
	var crown := deck + Vector3.UP * 5.62
	var top := crown.y - 0.51
	for side in [-1.0, 1.0]:
		var base: Vector3 = deck + upright.x * (width * side)
		base.y = _footing(base)
		_pillar(base, top, Vector2(0.62, 0.62), Color("#435258"), upright)
		_prop("beveled", base + Vector3.UP * 0.22, Vector3(1.12, 0.49, 1.05), Color("#697571"), upright)
		_box(Vector3(base.x, top - 1.23, base.z) + upright.z * 0.308,
			Vector3(0.12, 1.42, 0.04), accent, upright, _track.track_id == "docas")
	var size := Vector3(width * 2.0 + 1.05, 1.96, 0.64)
	_route_board(crown, size, upright, title, "", accent, Color("#283941"))
	_box(crown + Vector3.UP * 1.001, Vector3(size.x + 0.08, 0.065, 0.69), accent, upright)


func _road_sign(distance: float, side: float, text: String, accent: Color) -> void:
	var frame := _frame(distance)
	var upright := _basis(frame)
	var base: Vector3 = frame.position + frame.right * side * (_track.half_width + 4.4)
	base.y = _footing(base)
	_pillar(base, base.y + 1.65, Vector2(0.12, 0.14), Color("#5a655f"), upright)
	_route_board(base + Vector3.UP * 1.65, Vector3(2.18, 0.71, 0.145), upright, text, "", accent, DIRECTIONS)
	_box(base + Vector3.UP * 2.012, Vector3(2.18, 0.047, 0.16), accent, upright)


func _speedway() -> void:
	var graphite := Color("#526264")
	var panel := Color("#7f9594")
	var stand: Dictionary = _frame(56)
	var upright := _basis(stand)
	var canopy: Vector3 = stand.position - upright.x * 20.7
	canopy.y = _footing(canopy)
	_reserve(canopy, Vector2(16, 101), upright)
	_box(canopy + Vector3.UP * 0.02, Vector3(15.0, 0.14, 95.4), Color("#697575"), upright)
	for row in 8:
		var rise := 0.63 + row * 0.55
		var side := 5.20 - row * 1.37
		var deck := canopy + upright.x * side + Vector3.UP * rise
		_box(deck - Vector3.UP * (rise * 0.5 + 0.022), Vector3(1.37, rise + 0.05, 89.0), graphite, upright)
		_box(deck + Vector3.UP * 0.018, Vector3(1.34, 0.073, 88.22), Color("#a6a89c"), upright)
		var seats := Color("#6b8e93") if row % 3 != 0 else Color("#a49a77")
		for section in 5:
			var bench: Vector3 = deck + stand.forward * ((float(section) - 2.0) * 17.1) + Vector3.UP * 0.148
			_box(bench, Vector3(0.78, 0.20, 15.6), seats, upright)
			_box(bench - upright.x * 0.29 + Vector3.UP * 0.12, Vector3(0.16, 0.22, 15.4), seats.darkened(0.15), upright)
	for i in 8:
		var d := (i - 3.5) * 12.5
		var pier: Vector3 = canopy + stand.forward * d
		pier.y = canopy.y
		_pillar(pier - upright.x * 6.9, canopy.y + 7.22, Vector2(0.42, 0.45), graphite, upright)
		_beam(pier - upright.x * 6.9 + Vector3.UP * 5.51,
			pier + upright.x * 3.9 + Vector3.UP * 7.20, 0.22, 0.27, graphite)
	_box(canopy + Vector3.UP * 7.27, Vector3(14.8, 0.19, 100.2), panel, upright)
	_box(canopy + upright.x * 7.36 + Vector3.UP * 7.23, Vector3(0.23, 0.35, 100.2), ORANGE.darkened(0.16), upright)
	var pit := _frame(47)
	var pit_basis := _basis(pit)
	var apron: Vector3 = pit.position + pit_basis.x * 21.0 + pit_basis.z * -5.0
	apron.y = _footing(apron)
	_reserve(apron, Vector2(16.5, 69.0), pit_basis)
	_box(apron + Vector3.UP * 0.032, Vector3(16.4, 0.125, 68.8), Color("#7f8376"), pit_basis)
	for i in 9:
		var p: Vector3 = pit.position + pit_basis.x * 22.8 + pit.forward * ((i - 3.8) * 7.2)
		p.y = apron.y + 0.09
		_box(p + Vector3.UP * 1.95, Vector3(10.4, 3.90, 7.0), panel.darkened(0.16), pit_basis)
		var door: Vector3 = p - pit.right * 5.23
		_box(door + Vector3.UP * 1.47, Vector3(0.12, 2.86, 5.75), Color("#3e4e53"), pit_basis)
		_box(door - pit.right * 0.073 + Vector3.UP * 1.63, Vector3(0.04, 2.47, 5.44), Color("#6c7a78"), pit_basis)
		for tread in [0.65, 1.15, 1.65, 2.15, 2.65]:
			_box(door - pit.right * 0.10 + Vector3.UP * tread, Vector3(0.022, 0.032, 5.41), graphite, pit_basis)
		_box(door - pit.right * 0.13 + Vector3.UP * 3.07, Vector3(0.19, 0.20, 5.73), ORANGE, pit_basis)
	var pit_roof: Vector3 = pit.position + pit_basis.x * 22.8 + pit.forward * 1.44
	pit_roof.y = apron.y + 4.01
	_box(pit_roof, Vector3(12.2, 0.27, 66.6), Color("#a4aaa0"), pit_basis)
	var control: Vector3 = pit.position + pit_basis.x * 37.6 + pit.forward * 15.0
	control.y = _footing(control)
	_reserve(control, Vector2(15.3, 16.1), pit_basis)
	_box(control + Vector3.UP * 5.38, Vector3(13, 10.80, 14), graphite, pit_basis)
	_box(control + Vector3.UP * 10.95, Vector3(15.3, 0.62, 16.1), ORANGE.darkened(0.22), pit_basis)
	_box(control + Vector3.UP * 9.63, Vector3(13.12, 1.70, 14.12), Color("#88a6af"), pit_basis)
	for panel_z in [-5.4, -1.8, 1.8, 5.4]:
		_box(control - pit.right * 6.61 + pit.forward * panel_z + Vector3.UP * 9.63, Vector3(0.11, 1.71, 0.083), graphite, pit_basis)
	for d in [25.0, 98.0, 167.0, 269.0, 354.0, 449.0, 568.0, 688.0, 796.0, 936.0, 1060.0]:
		if d < _track.length - 10:
			_floodlight(d, 1.0 if fmod(d, 2.0) == 0.0 else -1.0, WHITE)
	_road_sign(_track.length - 28.0, 1.0, "BOXES", ORANGE)
	_sponsor(135.0, -1.0, "CANDEIA", "MOTOR CLUBE", ORANGE)
	_sponsor(_track.length * 0.48, -1.0, "ZARCO", "COMPONENTES", CYAN)
	_sponsor(_track.length * 0.75, 1.0, "VALE", "AUTOMOTIVO", ORANGE)
	_rails(15, Color("#9caaa7"), true)
	_speedway_infield()
	_speedway_horizon()


func _speedway_infield() -> void:
	for sector in range(0, 6):
		var distance: float = _track.length * (0.18 + sector * 0.124)
		var frame := _frame(distance)
		var side := -1.0 if sector % 3 != 0 else 1.0
		var upright := _basis(frame)
		var center: Vector3 = frame.position + frame.right * side * (_track.half_width + 23.0)
		if not _reserve(center, Vector2(22.0, 31.0), upright):
			continue
		center.y = _footing(center)
		var roof := ORANGE.darkened(0.24) if sector % 2 == 0 else Color("#819590")
		_box(center + Vector3.UP * 0.05, Vector3(16.8, 0.14, 25.0), Color("#626d67"), upright)
		_box(center + Vector3.UP * 2.0, Vector3(9.4, 3.77, 13.0), Color("#546464"), upright)
		_box(center + Vector3.UP * 3.94, Vector3(11.2, 0.32, 14.9), roof, upright)
		_box(center + Vector3.UP * 2.28 - frame.right * side * 4.74, Vector3(0.16, 0.90, 10.8), Color("#9aa99c"), upright)
		for i in 5:
			var flag: Vector3 = center + frame.forward * ((i - 2) * 6.1) - frame.right * side * 9.9
			_box(flag + Vector3.UP * 2.13, Vector3(0.08, 4.6, 0.08), Color("#74847e"), upright)
			_box(flag + Vector3.UP * 3.78, Vector3(0.09, 1.36, 1.04), ORANGE if i % 2 == 0 else CYAN, upright)
		if _quality > 0:
			for i in 3:
				var convoy: Vector3 = center + frame.forward * 20.0 + frame.right * (i - 1) * 3.3
				if _reserve(convoy, Vector2(2.1, 4.25), upright, 0.7):
					convoy.y = _footing(convoy)
					_service_van(convoy, upright, [WHITE, Color("#8ca5a1"), ORANGE][i % 3])


func _speedway_horizon() -> void:
	var base_hill := Color("#77867c")
	for i in range(12 if _quality == 0 else 22):
		var angle := i * TAU / 20.0
		var radius := 305.0 + _rng.randf_range(18, 86)
		var base := Vector3(108 + cos(angle) * radius, -18, 58 + sin(angle) * radius)
		_prop("morro", base, Vector3(135, _rng.randf_range(36, 80), 150), base_hill.lightened(_rng.randf_range(-0.13, 0.12)), Basis(Vector3.UP, angle))
	for i in range(38 if _quality == 0 else 94):
		var a := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(116, 270)
		var at := Vector3(103, 2.3, 45) + Vector3(cos(a), 0.0, sin(a)) * radius
		var size := _rng.randf_range(3.0, 6.35)
		var basis := Basis(Vector3.UP, a)
		if _reserve(at, Vector2.ONE * size * 0.68, basis, 4.0):
			at.y = _footing(at)
			_tree(at, size, Color("#56716a").lightened(_rng.randf_range(-0.16, 0.13)), basis)


func _docks() -> void:
	var slate := Color("#53616d")
	var colors: Array[Color] = [Color("#a56d55"), Color("#5e7887"), Color("#9a8969"), Color("#4f726f"), Color("#765a67")]
	for i in (6 if _quality == 0 else 9):
		var at := Vector3(18.5 + (i % 3) * 2.3, 0, -15.0 + i * 21.0)
		if _reserve(at, Vector2(2.58, 12.02), Basis.IDENTITY, 2.4):
			at.y = _footing(at)
			_container_stack(at, i, colors, Basis.IDENTITY, 1 if i % 4 == 2 else 2)
	for i in (3 if _quality == 0 else 5):
		var at := Vector3(45.5 + (i % 2) * 6.0, 0, 20 + i * 41.0)
		if _reserve(at, Vector2(20.5, 35.4), Basis.IDENTITY, 2.4):
			at.y = _footing(at)
			_warehouse(at, i, slate)
	for i in 4:
		var base := Vector3(-19.0, 0.0, 26.0 + i * 56.0)
		if _reserve(base, Vector2(11.6, 12.5), Basis.IDENTITY):
			base.y = _footing(base)
			_dock_crane(base, i)
	_prop("cargueiro", Vector3(-57.0, -1.06, 91.0), Vector3(29.0, 13.1, 124.0), Color.WHITE)
	_box(Vector3(-247.0, -0.97, 146.0), Vector3(95.0, 1.36, 570.0), slate.darkened(0.28))
	for i in range(16 if _quality == 0 else 25):
		var z := -120.0 + i * 22.0
		var x := -240.0 + _rng.randf_range(-35, 30)
		var h := _rng.randf_range(3.8, 28.0)
		_box(Vector3(x, h * 0.5 - 2.0, z), Vector3(_rng.randf_range(13, 27), h, _rng.randf_range(9, 15)), slate.darkened(_rng.randf_range(0.14, 0.58)))
	for i in range(10, int(_track.length), 42 if _quality == 0 else 29):
		_floodlight(i, -1.0 if i % 2 == 0 else 1.0, Color("#ffd291"), true)
	_dock_yards(colors)
	_sponsor(67.0, 1.0, "06", "CARGA LESTE", CYAN)
	_sponsor(_track.length * 0.57, -1.0, "FERRUGEM", "TERMINAL DE CARGAS", ORANGE)
	_rails(17, Color("#526e78"), true)
	var street: Surface = Surface.new()
	for i in 23:
		var z := -10.0 + i * 9.0
		var x := -16.9
		street.quad(Vector3(x, 0.449, z), Vector3(x + 0.10, 0.449, z), Vector3(x + 0.10, 0.449, z + 5.5), Vector3(x, 0.449, z + 5.5), Color("#9b8256"))
	_place_surface("Faixas do cais", street, 1.0)


func _dock_yards(colors: Array[Color]) -> void:
	var patch := 0
	for distance in range(245, int(_track.length) - 28, 125):
		var frame := _frame(distance)
		var upright := _basis(frame)
		for side in [-1.0, 1.0]:
			for slot in (2 if _quality == 0 else 3):
				var center: Vector3 = frame.position + frame.forward * ((slot - 1) * 15.0)
				center += upright.x * side * (_track.half_width + 8.6)
				if _reserve(center, Vector2(2.58, 12.02), upright, 2.2):
					center.y = _footing(center)
					_container_stack(center, slot + patch, colors, upright, 1 + int((slot + patch) % 3 == 0))
			var shed: Vector3 = frame.position + upright.x * side * (31.5 + (patch % 2) * 9.0)
			if _reserve(shed, Vector2(20.0, 32.0), upright, 3.0):
				shed.y = _footing(shed)
				var shell := Color("#556775").darkened((patch % 4) * 0.05)
				_prop("galpao", shed, Vector3(19.5, 8.47, 30.0), shell.lightened(0.22), upright)
				var van: Vector3 = shed + frame.forward * 18.7 - upright.x * side * 5.5
				if patch % 3 == 0 and _reserve(van, Vector2(2.05, 4.36), upright):
					van.y = _footing(van)
					_service_van(van, upright, ORANGE.darkened(0.16))
		patch += 1


func _service_van(at: Vector3, upright: Basis, color: Color) -> void:
	var van := CarArt.create({"model": "furgao_servico", "color": color}, _quality, true)
	van.transform = Transform3D(upright, at + Vector3.UP * 0.015)
	var shadow := Style.shadow(2.32, 4.53, 0.63, true)
	shadow.position.y = -0.009
	van.add_child(shadow)
	add_child(van)

func _container_stack(at: Vector3, palette: int, colors: Array[Color], orientation: Basis, levels: int) -> void:
	for i in levels:
		var center := at + Vector3.UP * ((i + 0.5) * 2.43 - 0.028)
		_container(center, colors[(palette + i * 2) % colors.size()], orientation)


func _container(at: Vector3, color: Color, orientation: Basis) -> void:
	var local := orientation * Basis(Vector3.UP, PI * 0.5)
	_prop("conteiner", at - Vector3.UP * 1.215, Vector3(11.8, 2.43, 2.41), color.lightened(0.28), local)


func _warehouse(at: Vector3, number: int, color: Color) -> void:
	var facade := color.lightened(0.22 + (number % 3) * 0.08)
	_prop("galpao", at, Vector3(20.2, 9.48, 35.0), facade)

func _dock_crane(at: Vector3, index: int) -> void:
	var metal := Color("#655d64").lightened(index * 0.041)
	for z in [-5.4, 5.4]:
		for x in [-4.8, 4.8]:
			_box(at + Vector3(x, 10.6, z), Vector3(0.66, 21.3, 0.78), metal)
			_box(at + Vector3(x, 0.29, z), Vector3(1.70, 0.59, 1.64), Color("#515a62"))
		_beam(at + Vector3(-4.8, 13.3, z), at + Vector3(4.8, 20.98, z), 0.30, 0.34, metal)
		_beam(at + Vector3(4.8, 13.3, z), at + Vector3(-4.8, 20.98, z), 0.30, 0.34, metal)
		_box(at + Vector3(-10.1, 21.17, z), Vector3(35, 0.42, 0.65), metal)
		_box(at + Vector3(-10.1, 23.06, z), Vector3(35, 0.39, 0.56), metal)
		for bay in 8:
			var x := -27.55 + float(bay) * 4.36
			_beam(at + Vector3(x, 21.19, z), at + Vector3(x + 2.18, 23.03, z), 0.22, 0.25, metal)
			_beam(at + Vector3(x + 2.18, 23.03, z), at + Vector3(x + 4.36, 21.19, z), 0.22, 0.25, metal)
		_box(at + Vector3(-27.27, 16.61, z), Vector3(0.075, 9.0, 0.075), Color("#3a4554"))
	_prop("beveled", at + Vector3(-4.81, 19.55, 5.51), Vector3(2.13, 1.67, 2.11), metal.lightened(0.17))
	_box(at + Vector3(-4.81, 19.85, 6.57), Vector3(1.55, 0.61, 0.05), Color("#637b87"))
	_box(at + Vector3(-27.30, 12.0, 0), Vector3(2.11, 0.44, 11.27), metal.lightened(0.16))
	_box(at + Vector3(4.9, 23.23, 0), Vector3(0.23, 0.25, 11.10), ORANGE, Basis.IDENTITY, true)


func _mountains() -> void:
	_rails(9 if _quality != 0 else 17, Color("#a5a5a0"), false)
	_road_sign(47.0, 1.0, "BR-63", Color("#d0d5c3"))
	_road_sign(_track.length * 0.45, 1.0, "KM 04", Color("#d0d5c3"))
	_sponsor(83.0, -1.0, "SERRA DA LUA", "RESERVA DO ALTO", Color("#e9be88"))
	var mountain_color := Color("#838f91")
	var bounds: Rect2 = _track.bounds()
	var world_center := Vector3(bounds.get_center().x, 0, -bounds.get_center().y)
	for i in range(22 if _quality == 0 else 40):
		var angle := i * 0.26 + _rng.randf_range(-0.04, 0.04)
		var radius := maxf(bounds.size.x, bounds.size.y) * 0.63 + _rng.randf_range(69.0, 226.0)
		var at := world_center + Vector3(cos(angle) * radius, -29.0, sin(angle) * radius)
		var dimensions := Vector3(_rng.randf_range(100, 275), _rng.randf_range(68, 159), _rng.randf_range(88, 260))
		_prop("morro", at, dimensions, mountain_color.lightened(_rng.randf_range(-0.23, 0.16)), Basis(Vector3.UP, angle))
	var stride := 26 if _quality == 0 else 18
	for distance in range(3, int(_track.length), stride):
		var frame := _frame(distance)
		var p: Vector3 = frame.position
		var right: Vector3 = frame.right
		var steep: float = absf(frame.curvature)
		for side in [-1.0, 1.0]:
			var count := 2 if _quality == 0 else 3
			for i in count:
				var offset: float = side * _rng.randf_range(_track.half_width + 6.0, _track.half_width + 23.0)
				var wave: float = _rng.randf_range(-6.0, 6.0)
				var location: Vector3 = p + right * offset + frame.forward * wave
				var basis := Basis(Vector3.UP, _rng.randf() * TAU)
				var height := _rng.randf_range(1.8, 5.1)
				if i == 0 or _rng.randf() > 0.57:
					var size := Vector3(height * 1.18, height * 0.69, height * 0.95)
					if _reserve(location, Vector2(size.x, size.z), basis, 2.3):
						var bottom := size.y * 0.30
						location.y = _footing(location) + bottom
						var variant := "rocha_1" if (distance + i) % 2 == 0 else "rocha_2"
						_prop(variant, location, size, Color("#8c8374").lightened(_rng.randf_range(0.13, 0.39)), basis)
				else:
					if _reserve(location, Vector2.ONE * height * 0.73, basis, 2.5):
						location.y = _footing(location)
						var leaf := Color("#526c57").lightened(_rng.randf_range(-0.16, 0.16))
						_tree(location, height, leaf, basis)
		if steep > 0.017:
			_chevron(distance, signf(frame.curvature))


func _tree(at: Vector3, height: float, leaf: Color, basis: Basis) -> void:
	var variant := "arvore_1" if fposmod(at.x + at.z, 2.0) < 1.0 else "arvore_2"
	_prop(variant, at - Vector3.UP * 0.035, Vector3.ONE * height * 1.05, leaf.lightened(0.30), basis)


func _chevron(distance: float, side: float) -> void:
	var frame := _frame(distance)
	var basis := _basis(frame)
	var base: Vector3 = frame.position + frame.right * side * (_track.half_width + 3.25)
	base.y = _footing(base)
	_pillar(base, base.y + 1.40, Vector2(0.10, 0.11), Color("#8a8a75"), basis)
	_route_board(base + Vector3.UP * 1.4, Vector3(0.98, 0.73, 0.11), basis,
		"›" if side < 0.0 else "‹", "", Color("#403631"), Color("#cfa256"), Color("#403631"))


func _rails(spacing: int, shade: Color, both: bool) -> void:
	var length: float = _track.length
	var spans := ceili(length / float(spacing))
	for side in [-1.0, 1.0]:
		var setback: float = side * (_track.half_width + 2.18)
		var built := false
		for i in spans:
			var first := length * i / float(spans)
			var last := length * (i + 1) / float(spans)
			var active: bool = both or side < 0.0 or i % 9 < 5
			if not active:
				if built:
					_rail_post(_rail_point(first, setback), shade, _basis(_frame(first)))
				built = false
				continue
			var a := _rail_point(first, setback)
			_rail_post(a, shade, _basis(_frame(first)))
			var segments := 2 if absf(float(_frame((first + last) * 0.5).curvature)) > 0.0035 else 1
			for j in range(1, segments + 1):
				var b := _rail_point(lerpf(first, last, j / float(segments)), setback)
				_beam(a, b, 0.14, 0.28, shade.darkened(0.12))
				_beam(a + Vector3.UP * 0.103, b + Vector3.UP * 0.103, 0.181, 0.056, shade)
				a = b
			built = true
		if not _track.closed and built:
			_rail_post(_rail_point(length, setback), shade, _basis(_frame(length)))


func _rail_point(distance: float, setback: float) -> Vector3:
	var frame: Dictionary = _track.pavement_frame(distance)
	var point: Vector3 = frame.position + frame.right * setback
	point.y = _footing(point) + 0.74
	return point


func _rail_post(at: Vector3, shade: Color, basis: Basis) -> void:
	var foot := at - Vector3.UP * 0.74
	_pillar(foot, at.y + 0.06, Vector2(0.15, 0.17), shade.darkened(0.41), basis)
	_box(at + Vector3.UP * 0.152, Vector3(0.16, 0.069, 0.19), shade.lerp(ORANGE, 0.48), basis)


func _floodlight(distance: float, side: float, accent: Color, docks := false) -> void:
	var frame := _frame(distance)
	var base: Vector3 = frame.position + frame.right * side * (_track.half_width + (3.4 if docks else 7.4))
	var upright := _basis(frame)
	var h := 6.3 if docks else 11.2
	base.y = _footing(base)
	_pillar(base, base.y + h, Vector2(0.14, 0.14), Color("#657178"), upright)
	_prop("beveled", base + Vector3.UP * 0.126, Vector3(0.30, 0.28, 0.33), Color("#576269"), upright)
	_box(base + Vector3.UP * h - upright.x * side * 0.63, Vector3(1.43, 0.19, 0.28), Color("#57626a"), upright)
	for i in 2 if docks else 4:
		var light_at: Vector3 = base + Vector3.UP * (h - 0.032) - upright.x * side * (0.19 + i * 0.31) + upright.z * 0.141
		_box(light_at, Vector3(0.243, 0.097, 0.025), accent, upright, true)
	if docks:
		var at: Vector3 = frame.position + frame.right * side * (_track.half_width - 1.4) + Vector3.UP * 0.017
		_prop("spill", at, Vector3(12.8, 1.0, 14.0), accent.darkened(0.22), upright)


func _sponsor(distance: float, side: float, title: String, subtitle: String, accent: Color) -> void:
	var frame := _frame(distance)
	var upright := _basis(frame)
	var base: Vector3 = frame.position + frame.right * side * (_track.half_width + 8.8)
	if not _reserve(base, Vector2(7.55, 0.68), upright, 1.5):
		return
	var top: float = _footing(base) + 3.72
	for x in [-2.62, 2.62]:
		var foot: Vector3 = base + upright.x * x
		foot.y = _footing(foot)
		_pillar(foot, top - 1.58, Vector2(0.17, 0.18), Color("#849595"), upright)
	base.y = top - 0.91
	_route_board(base, Vector3(7.44, 1.82, 0.26), upright, title, subtitle, accent, Color("#34434a"))
	_box(base + Vector3.UP * 0.922, Vector3(7.46, 0.055, 0.29), accent, upright)


func _basis(frame: Dictionary) -> Basis:
	var right: Vector3 = frame.right
	return Basis(right, Vector3.UP, right.cross(Vector3.UP)).orthonormalized()


func _place_surface(title: String, surface: Surface, roughness: float, finish_name := "", tile := 1.0) -> void:
	if surface.vertices.is_empty():
		return
	var shape := MeshInstance3D.new()
	shape.name = title
	shape.mesh = surface.make_mesh(roughness, finish_name, tile)
	if title != "Terreno" and title != "Asfalto":
		shape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shape)


func _route_board(at: Vector3, size: Vector3, basis: Basis, title: String, detail: String,
		accent: Color, background: Color, lettering := WHITE) -> void:
	_prop("beveled", at, size, background, basis)
	Placard.panel(self, Transform3D(basis, at + basis.z * (size.z * 0.5)),
		Vector2(size.x, size.y), title, detail, lettering, accent)


func _pillar(foot: Vector3, top: float, size: Vector2, tint: Color, basis: Basis) -> void:
	var low := foot.y - 0.07
	var support := Vector3(foot.x, (low + top) * 0.5, foot.z)
	_box(support, Vector3(size.x, maxf(0.10, top - low), size.y), tint, basis)


func _box(at: Vector3, dimensions: Vector3, shade: Color, orientation := Basis.IDENTITY, emissive := false) -> void:
	_prop("glow" if emissive else "box", at, dimensions, shade, orientation)


func _beam(from: Vector3, to: Vector3, width: float, depth: float, shade: Color) -> void:
	var span := to - from
	var up := Vector3.BACK if absf(span.normalized().y) > 0.98 else Vector3.UP
	_box((from + to) * 0.5, Vector3(width, depth, span.length()), shade, Basis.looking_at(span, up))


func _prop(kind: String, at: Vector3, dimensions: Vector3, shade: Color, orientation := Basis.IDENTITY) -> void:
	if not _batches.has(kind):
		_batches[kind] = {}
	var cell := Vector2i(floori(at.x / PROP_CELL), floori(at.z / PROP_CELL))
	var chunks: Dictionary = _batches[kind]
	if not chunks.has(cell):
		chunks[cell] = []
	var basis := Basis(orientation.x * dimensions.x, orientation.y * dimensions.y, orientation.z * dimensions.z)
	chunks[cell].append([Transform3D(basis, at), shade])


func _flush_batches() -> void:
	for key: String in _batches:
		var mesh := _get_prop_mesh(key)
		var chunks: Dictionary = _batches[key]
		for cell: Vector2i in chunks:
			var batch: Array = chunks[cell]
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = true
			multimesh.mesh = mesh
			multimesh.instance_count = batch.size()
			for i in batch.size():
				multimesh.set_instance_transform(i, batch[i][0])
				multimesh.set_instance_color(i, batch[i][1])
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			if key == "beveled":
				var paint := StandardMaterial3D.new()
				paint.vertex_color_use_as_albedo = true
				paint.roughness = 0.75
				instance.material_override = paint
			if key in ["glow", "spill", "morro"] or _quality != 2:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)
	_batches.clear()


func _get_prop_mesh(key: String) -> Mesh:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	if key == "spill":
		return _light_spill()
	if key == "beveled":
		return Forms.cabinet()
	if key in ["conteiner", "arvore_1", "arvore_2", "rocha_1", "rocha_2", "morro", "cargueiro", "galpao"]:
		return Models.prop(key)
	if key == "glow":
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var block := BoxMesh.new()
	block.size = Vector3.ONE
	block.material = material
	return block


func _light_spill() -> Mesh:
	var mesh := ArrayMesh.new()
	var geometry := Surface.new()
	for i in 12:
		var a := i * TAU / 12.0
		var b := (i + 1) * TAU / 12.0
		geometry.vertices.append(Vector3.ZERO)
		geometry.vertices.append(Vector3(cos(a), 0, sin(a)) * 0.5)
		geometry.vertices.append(Vector3(cos(b), 0, sin(b)) * 0.5)
		geometry.colors.append(Color(1, 1, 1, 0.135))
		geometry.colors.append(Color(1, 1, 1, 0))
		geometry.colors.append(Color(1, 1, 1, 0))
		for j in 3:
			geometry.normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = geometry.vertices
	arrays[Mesh.ARRAY_NORMAL] = geometry.normals
	arrays[Mesh.ARRAY_COLOR] = geometry.colors
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh
