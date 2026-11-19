extends Node3D
## Procedural meshes and scenery batches. Props share a small set of instanced meshes.

const WHITE := Color("#eee8d7")
const ORANGE := Color("#ed8c43")
const CYAN := Color("#69c7c5")
const DIRECTIONS := Color("#203c42")
const PROP_CELL := 144.0

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

	func make_mesh(roughness: float) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = roughness
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		return mesh

var _track: Node3D
var _config: Dictionary
var _quality := 1
var _rng := RandomNumberGenerator.new()
var _batches: Dictionary


func build(track: Node3D, config: Dictionary) -> void:
	_track = track
	_config = config
	_quality = track.quality
	_rng.seed = track.track_id.hash()
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


func _sky() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = _config.sky_top
	sky_material.sky_horizon_color = _config.sky_horizon
	sky_material.ground_horizon_color = _config.sky_horizon
	sky_material.ground_bottom_color = _config.sky_bottom
	sky_material.sky_curve = 0.24
	sky_material.sun_angle_max = 11.0
	sky_material.sun_curve = 0.14
	var sky := Sky.new()
	sky.sky_material = sky_material
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = _config.ambient
	settings.ambient_light_energy = _config.ambient_energy
	settings.fog_enabled = _quality > 0
	settings.fog_light_color = _config.fog
	settings.fog_density = _config.fog_density
	settings.fog_sky_affect = 0.36
	var world := WorldEnvironment.new()
	world.environment = settings
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28, -125, 0)
	light.light_color = _config.sun
	light.light_energy = _config.sun_energy
	light.shadow_enabled = _quality == 2
	light.directional_shadow_max_distance = 95.0
	add_child(light)


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
		surface.quad(Vector3(-540, -1.1, z0 - 190), Vector3(x0, -1.1, z0 - 190), Vector3(x0, -1.1, z1 + 190), Vector3(-540, -1.1, z1 + 190), Color("#294854"))
		for i in 30:
			var z := z0 + i * (z1 - z0) / 30.0
			_box(Vector3(x0 + 0.65, 0.12, z), Vector3(1.18, 1.58, (z1 - z0) / 30.0 - 0.35), Color("#49545b"))
	var step := 30.0 if not mountain else (15.0 if _quality == 0 else 12.0)
	var dx := ceili((x1 - x0) / step)
	var dz := ceili((z1 - z0) / step)
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
	for row in dz:
		for column in dx:
			var i := row * (dx + 1) + column
			var a := grid[i]
			var b := grid[i + 1]
			var c := grid[i + dx + 2]
			var d := grid[i + dx + 1]
			var shade := clampf(0.55 + 0.20 * sin(column * 0.55 + row * 0.34) + _rng.randf_range(-0.13, 0.13), 0.12, 0.88)
			var base: Color = _config.ground_a.lerp(_config.ground_b, shade)
			surface.triangle(a, b, c, base, (c - a).cross(b - a).normalized())
			surface.triangle(a, c, d, base.darkened(_rng.randf_range(0.0, 0.034)), (d - a).cross(c - a).normalized())
	_place_surface("Terreno", surface, 1.0)


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
	var paint := Surface.new()
	var width: float = _track.half_width
	var road_color: Color = _config.road
	var shoulder: Color = _config.shoulder
	var mountain: bool = _track.track_id == "serra" and _track.mode != "drag"
	var start := 0.0 if _track.closed else -32.0
	var end: float = _track.length if _track.closed else _track.length + 44.0
	var divisions := ceili((end - start) / 4.0)
	var current := _frame(start)
	for i in divisions:
		var d := lerpf(start, end, (i + 1) / float(divisions))
		var next := _frame(d)
		var shade := (sin(i * 0.27) - 0.08) * 0.023
		_strip(road, current, next, -width, width, 0, 0, road_color.lightened(shade))
		if not mountain and _track.mode != "drag":
			for lane in [-1.68, 1.68]:
				_strip(road, current, next, lane - 0.55, lane + 0.55, 0.008, 0.008, road_color.darkened(0.046 + 0.02 * sin(i * 0.19)))
		for side in [-1.0, 1.0]:
			_strip(road, current, next, side * width, side * (width + 1.35), -0.01, -0.08, shoulder)
			var verge: Color = _config.ground_a.lerp(_config.ground_b, 0.39)
			if mountain:
				_strip(road, current, next, side * (width + 1.35), side * (width + 10.0), -0.08, -2.65, verge)
			else:
				_strip(road, current, next, side * (width + 1.35), side * (width + 4.4), -0.08, -1.28, verge)
			var curb: Color = _config.curb_a if i % 2 == 0 else _config.curb_b
			if _track.mode != "drag" and _track.track_id != "serra":
				_strip(paint, current, next, side * width, side * (width + 0.62), 0.019, 0.008, curb)
			_strip(paint, current, next, side * (width - 0.23), side * (width - 0.07), 0.021, 0.021, _config.stripe)
		current = next
	if _track.mode == "drag":
		_line(paint, -20.0, _track.length + 26.0, -0.09, 0.09, _config.stripe)
	else:
		_midline(paint)
	_grid(paint)
	var finish: float = 0.0 if _track.closed else _track.length
	_checkered(paint, finish, width)
	if not _track.closed:
		_line(paint, _track.start_line, _track.start_line + 0.22, -width, width, WHITE)
	_place_surface("Asfalto", road, 0.85 if _track.track_id == "docas" else 0.98)
	_place_surface("Sinalização horizontal", paint, 0.92)


func _strip(surface: Surface, a: Dictionary, b: Dictionary, left: float, right: float, y_left: float, y_right: float, color: Color) -> void:
	var ap: Vector3 = a.position
	var bp: Vector3 = b.position
	var ar: Vector3 = a.right
	var br: Vector3 = b.right
	surface.quad(
		ap + ar * left + Vector3.UP * y_left, ap + ar * right + Vector3.UP * y_right,
		bp + br * right + Vector3.UP * y_right, bp + br * left + Vector3.UP * y_left, color,
	)


func _line(surface: Surface, first: float, last: float, left: float, right: float, color: Color, h := 0.024) -> void:
	var segments := maxi(1, ceili((last - first) / 3.8))
	var previous := _frame(first)
	for i in range(1, segments + 1):
		var next := _frame(lerpf(first, last, i / float(segments)))
		_strip(surface, previous, next, left, right, h, h, color)
		previous = next


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
	var width: float = _track.half_width
	if _track.mode == "drag":
		for d in [5.0, 105.0, 205.0, 305.0]:
			for side in [-1.0, 1.0]:
				_line(paint, d, d + 0.20, side * (width - 0.35), side * (width - 1.90), WHITE)
		return
	for i in 3:
		var d := 1.5 + 6.0 * i
		for side in [-1.0, 1.0]:
			var lane: float = side * 1.7
			_line(paint, d, d + 0.15, lane - 1.12, lane + 1.12, WHITE, 0.029)
			for inset in [-1.12, 1.12]:
				_line(paint, d, d + 0.82, lane + inset - 0.07, lane + inset + 0.07, WHITE, 0.029)


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
	var heading := "CANDEIA  /  CIRCUITO"
	var subheading := "VALE DA CANDEIA"
	var accent := ORANGE
	match _track.track_id:
		"docas":
			heading = "CAIS FERRUGEM"
			subheading = "SETOR 06  •  ACESSO NORTE"
			accent = CYAN
		"serra":
			heading = "ALTO DA LUA"
			subheading = "BR-63  •  ROTA DA SERRA"
			accent = Color("#e7ba7f")
	if _track.mode == "drag":
		heading = "402 M  /  ARRANCADA"
	_gantry(_track.start_line + (9.0 if _track.mode == "drag" else 0.0), heading, subheading, accent)
	if not _track.closed:
		_gantry(_track.length + 0.8, "CHEGADA", "402 M" if _track.mode == "drag" else _track.route_name.to_upper(), accent)
		for mark in range(100, int(_track.length), 100):
			if _track.mode == "drag":
				_road_sign(mark + _track.start_line, 1.0, str(mark) + " M", accent)
			elif mark % 300 == 0:
				_road_sign(mark, -1.0, "%d M" % mark, accent)
	var frequency := 27 if _quality == 0 else 18
	for i in range(0, int(_track.length), frequency):
		var frame := _frame(i)
		var width: float = _track.half_width
		for side in [-1.0, 1.0]:
			var post: Vector3 = frame.position + frame.right * (side * (width + 1.43))
			_box(post + Vector3.UP * 0.19, Vector3(0.12, 0.57, 0.15), Color("#adb3a9"))
			_box(post + Vector3.UP * 0.40, Vector3(0.15, 0.10, 0.18), accent, Basis.IDENTITY, true)


func _gantry(distance: float, title: String, subtitle: String, accent: Color) -> void:
	var frame := _frame(distance)
	var width: float = _track.half_width + 2.5
	var upright := _basis(frame)
	var deck: Vector3 = frame.position
	for side in [-1.0, 1.0]:
		var base: Vector3 = deck + frame.right * (width * side)
		_box(base + Vector3.UP * 2.46, Vector3(0.62, 6.07, 0.64), Color("#435258"), upright)
		_box(base + Vector3.UP * 0.26, Vector3(1.35, 0.64, 1.18), Color("#68716a"), upright)
		_box(base + Vector3.UP * 3.67 - frame.forward * 0.33, Vector3(0.16, 2.30, 0.05), accent, upright, _track.track_id == "docas")
	_box(deck + Vector3.UP * 5.58, Vector3(width * 2.0 + 1.46, 1.96, 0.74), Color("#283941"), upright)
	_box(deck + Vector3.UP * 6.61, Vector3(width * 2.0 + 1.58, 0.14, 0.78), accent, upright, _track.track_id == "docas")
	_box(deck + Vector3.UP * 4.66, Vector3(width * 2.0 + 1.50, 0.16, 0.78), Color("#708380"), upright)
	for side in [-1.0, 1.0]:
		for i in 3:
			var right: Vector3 = frame.right * (side * (width - 0.6 - i * 0.34))
			_box(deck + right + Vector3.UP * (5.38 + i * 0.17) - frame.forward * 0.43, Vector3(0.21, 0.46, 0.05), accent, upright, true)
	_label(title, deck + Vector3.UP * 5.94 - frame.forward * 0.42, upright, 0.023, WHITE)
	_label(subtitle, deck + Vector3.UP * 5.10 - frame.forward * 0.43, upright, 0.010, accent)


func _road_sign(distance: float, side: float, text: String, accent: Color) -> void:
	var frame := _frame(distance)
	var upright := _basis(frame)
	var base: Vector3 = frame.position + frame.right * side * (_track.half_width + 2.7)
	_box(base + Vector3.UP * 0.85, Vector3(0.12, 1.74, 0.14), Color("#5a655f"), upright)
	_box(base + Vector3.UP * 1.63, Vector3(2.24, 0.73, 0.15), DIRECTIONS, upright)
	_box(base + Vector3.UP * 1.98, Vector3(2.24, 0.07, 0.17), accent, upright)
	_label(text, base + Vector3.UP * 1.65 - frame.forward * 0.09, upright, 0.009, WHITE)


func _speedway() -> void:
	var graphite := Color("#495c60")
	var panel := Color("#5e7275")
	var stand: Dictionary = _frame(56)
	var upright := _basis(stand)
	for row in range(5 if _quality == 0 else 8):
		var rise := row * 0.64
		var side := -15.5 - row * 1.42
		var base: Vector3 = stand.position + stand.right * side + Vector3.UP * (0.28 + rise)
		_box(base, Vector3(1.62, 0.53, 89), graphite, upright)
		_box(base + Vector3.UP * 0.27, Vector3(1.15, 0.09, 87.5), ORANGE.darkened(0.24 + row * 0.049), upright)
		if _quality != 0:
			for slot in 27:
				if _rng.randf() < 0.72:
					var d := (slot - 13.0) * 3.10
					var spectator: Vector3 = base + stand.forward * d + Vector3.UP * (0.57 + _rng.randf() * 0.16)
					_box(spectator, Vector3(0.29, 0.49, 0.24), [WHITE, ORANGE, graphite, CYAN][slot % 4], upright)
	var canopy: Vector3 = stand.position + stand.right * -20.7
	for i in 8:
		var d := (i - 3.5) * 12.5
		var pier: Vector3 = canopy + stand.forward * d
		_box(pier + stand.right * -6.9 + Vector3.UP * 3.72, Vector3(0.42, 7.43, 0.45), graphite, upright)
		_box(pier + Vector3.UP * 7.27, Vector3(14.8, 0.23, 12.0), panel, upright)
	_box(canopy + stand.right * 6.8 + Vector3.UP * 7.29, Vector3(0.25, 0.30, 99.0), ORANGE, upright)
	var pit := _frame(47)
	var pit_basis := _basis(pit)
	for i in 9:
		var p: Vector3 = pit.position + pit.right * 22.8 + pit.forward * ((i - 3.8) * 7.2)
		_box(p + Vector3.UP * 1.8, Vector3(10.4, 4.16, 7.0), graphite, pit_basis)
		_box(p - pit.right * 5.23 + Vector3.UP * 1.46, Vector3(0.07, 2.85, 5.7), Color("#2d393e"), pit_basis)
		_box(p - pit.right * 5.27 + Vector3.UP * 3.10, Vector3(0.11, 0.25, 5.7), ORANGE, pit_basis)
	_box(pit.position + pit.right * 22.8 + Vector3.UP * 3.97, Vector3(12.2, 0.35, 66.6), Color("#a4aaa0"), pit_basis)
	var control: Vector3 = pit.position + pit.right * 34.0 + pit.forward * 15.0
	_box(control + Vector3.UP * 5.27, Vector3(13, 11, 14), graphite, pit_basis)
	_box(control + Vector3.UP * 11.13, Vector3(15, 1.2, 16), ORANGE.darkened(0.2), pit_basis)
	_box(control + Vector3.UP * 9.63, Vector3(13.1, 1.7, 14.1), Color("#8ca2a4"), pit_basis)
	for d in [25.0, 98.0, 167.0, 269.0, 354.0, 449.0, 568.0, 688.0, 796.0, 936.0, 1060.0]:
		if d < _track.length - 10:
			_floodlight(d, 1.0 if fmod(d, 2.0) == 0.0 else -1.0, WHITE)
	_road_sign(105.0, 1.0, "BOX  /  100", ORANGE)
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
		if not _clear(center, 18.0):
			continue
		center.y = -0.13
		var roof := ORANGE.darkened(0.24) if sector % 2 == 0 else Color("#819590")
		_box(center + Vector3.UP * 0.20, Vector3(16.8, 0.35, 25.0), Color("#626d67"), upright)
		_box(center + Vector3.UP * 2.0, Vector3(9.4, 3.77, 13.0), Color("#546464"), upright)
		_box(center + Vector3.UP * 3.94, Vector3(11.2, 0.32, 14.9), roof, upright)
		_box(center + Vector3.UP * 2.28 - frame.right * side * 4.74, Vector3(0.16, 0.90, 10.8), Color("#9aa99c"), upright)
		for i in 5:
			var flag: Vector3 = center + frame.forward * ((i - 2) * 6.1) - frame.right * side * 9.9
			_box(flag + Vector3.UP * 2.13, Vector3(0.08, 4.6, 0.08), Color("#74847e"), upright)
			_box(flag + Vector3.UP * 3.78, Vector3(0.09, 1.36, 1.04), ORANGE if i % 2 == 0 else CYAN, upright)
		if _quality > 0:
			for i in 6:
				var convoy: Vector3 = center + frame.forward * (16.0 + (i / 3) * 5.1) + frame.right * (i % 3) * 3.0
				if _clear(convoy, 5.0):
					_service_van(convoy, upright, [WHITE, Color("#8ca5a1"), ORANGE][i % 3])


func _speedway_horizon() -> void:
	var base_hill := Color("#77867c")
	for i in range(12 if _quality == 0 else 22):
		var angle := i * TAU / 20.0
		var radius := 305.0 + _rng.randf_range(18, 86)
		var base := Vector3(108 + cos(angle) * radius, -18, 58 + sin(angle) * radius)
		_prop("peak", base, Vector3(135, _rng.randf_range(36, 80), 150), base_hill.lightened(_rng.randf_range(-0.13, 0.12)), Basis(Vector3.UP, angle))
	for i in range(38 if _quality == 0 else 94):
		var a := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(116, 270)
		var at := Vector3(103, 2.3, 45) + Vector3(cos(a), 0.0, sin(a)) * radius
		var model: Dictionary = _track.project(at)
		if absf(model.lateral) > _track.half_width + 11.0 and at.distance_to(model.position) > 31.0:
			var size := _rng.randf_range(3.0, 6.35)
			_prop("tree", at, Vector3(size * 0.74, size, size * 0.61), Color("#56716a").lightened(_rng.randf_range(-0.19, 0.13)), Basis(Vector3.UP, a))


func _docks() -> void:
	var slate := Color("#53616d")
	var colors: Array[Color] = [Color("#9b5c45"), Color("#536e7f"), Color("#987f56"), Color("#446663"), Color("#684d58")]
	for i in range(16 if _quality == 0 else 28):
		var z := -31.0 + i * 13.8
		var x := 18.0 + (i % 3) * 2.5
		_container(Vector3(x, 1.77, z), colors[i % colors.size()], Basis.IDENTITY)
		if i % 4 != 2:
			_container(Vector3(x + 2.42, 4.22, z + 0.22), colors[(i + 2) % colors.size()], Basis.IDENTITY)
		if i % 5 < 2 and _quality != 0:
			_container(Vector3(x + 4.83, 6.65, z + 0.22), colors[(i + 3) % colors.size()], Basis.IDENTITY)
	var warehouse_count := 3 if _quality == 0 else 6
	for i in warehouse_count:
		var at := Vector3(49.0 + (i % 2) * 8.0, 0.4, 24 + i * 38.0)
		_warehouse(at, i, slate)
	for i in 4:
		var z := 24.0 + i * 55.0
		_dock_crane(Vector3(-19.0, 0.46, z), i)
	_box(Vector3(-57, 0.4, 91), Vector3(29.0, 3.5, 124.0), Color("#222f3d"))
	_box(Vector3(-57, 2.40, 91), Vector3(27.7, 1.05, 122.0), Color("#8b6956"))
	_box(Vector3(-57, 3.47, 91), Vector3(25.5, 1.35, 117.0), slate)
	_box(Vector3(-61, 7.61, 57), Vector3(13, 9.6, 15), Color("#667587"))
	_box(Vector3(-61, 12.26, 57), Vector3(15.2, 1.18, 16.2), Color("#8394a0"))
	for i in range(12 if _quality == 0 else 23):
		var z := 33.0 + i * 5.2
		_box(Vector3(-48.45, 3.55, z), Vector3(1.65, 0.22, 2.2), Color("#e5bb70"), Basis.IDENTITY, true)
	for i in range(22 if _quality == 0 else 39):
		var z := -120.0 + i * 17
		var x := -240.0 + _rng.randf_range(-35, 30)
		var h := _rng.randf_range(3.8, 28.0)
		_box(Vector3(x, h * 0.5 - 2.0, z), Vector3(_rng.randf_range(13, 27), h, _rng.randf_range(9, 15)), slate.darkened(_rng.randf_range(0.14, 0.58)))
		if i % 3 == 1:
			_box(Vector3(x + 9, h * 0.7 - 2.0, z), Vector3(0.20, 0.31, 2.9), Color("#c89e60"), Basis.IDENTITY, true)
	for i in range(10, int(_track.length), 42 if _quality == 0 else 29):
		_floodlight(i, -1.0 if i % 2 == 0 else 1.0, Color("#ffd291"), true)
	_dock_yards(colors)
	_sponsor(67.0, 1.0, "06", "CARGA LESTE", CYAN)
	_sponsor(_track.length * 0.57, -1.0, "FERRUGEM", "TERMINAL DE CARGAS", ORANGE)
	_rails(17, Color("#526e78"), true)
	var street: Surface = Surface.new()
	for i in 23:
		var z := -10.0 + i * 9.0
		var x := -20.2 + (i % 2) * 0.4
		street.quad(Vector3(x, 0.449, z), Vector3(x + 0.11, 0.449, z), Vector3(x + 0.16, 0.449, z + 6.2), Vector3(x, 0.449, z + 6.2), Color("#9b8256"))
	_place_surface("Faixas do cais", street, 1.0)


func _dock_yards(colors: Array[Color]) -> void:
	var patch_count := ceili((_track.length - 224.0) / 114.0)
	for patch in range(patch_count):
		var frame := _frame(251.0 + patch * 114.0)
		var upright := _basis(frame)
		for side in [-1.0, 1.0]:
			for row in (1 if _quality == 0 else 2):
				for slot in range(3 if _quality == 0 else 5):
					var center: Vector3 = frame.position + frame.forward * ((slot - 2) * 13.0)
					center += frame.right * side * (_track.half_width + 5.7 + row * 4.7)
					if center.x < -23.5 or not _clear(center, 5.2):
						continue
					center.y = 0.44
					var color_index := (slot + row * 2 + patch) % colors.size()
					_container(center + Vector3.UP * 1.2, colors[color_index], upright)
					if (slot + row + patch) % 4 < 2:
						_container(center + Vector3.UP * 3.64, colors[(color_index + 1) % colors.size()], upright)
			var shed: Vector3 = frame.position + frame.right * side * (25.0 + (patch % 2) * 12.0)
			if shed.x > -15.0 and _clear(shed, 17.0):
				shed.y = 0.44
				var shell := Color("#556775").darkened((patch % 4) * 0.05)
				_box(shed + Vector3.UP * 4.0, Vector3(18.0, 8.1, 29.0), shell, upright)
				_box(shed + Vector3.UP * 8.13, Vector3(19.5, 0.67, 30.0), shell.darkened(0.33), upright)
				for door in 3:
					var entrance: Vector3 = shed + frame.forward * ((door - 1) * 8.0) - frame.right * side * 9.1
					_box(entrance + Vector3.UP * 2.03, Vector3(0.15, 4.10, 6.10), Color("#34454d"), upright)
					_box(entrance + Vector3.UP * 4.39, Vector3(0.24, 0.15, 5.87), Color("#f0c17d"), upright, true)
				if patch % 3 == 0:
					_service_van(shed + frame.forward * 17.6, upright, ORANGE.darkened(0.16))


func _service_van(at: Vector3, upright: Basis, color: Color) -> void:
	_box(at + Vector3.UP * 0.56, Vector3(1.85, 0.40, 4.2), Color("#354247"), upright)
	_box(at + Vector3.UP * 1.22 + upright.z * 0.26, Vector3(1.78, 1.37, 3.61), color, upright)
	_box(at + Vector3.UP * 1.47 - upright.z * 1.55, Vector3(1.70, 0.59, 0.11), Color("#546d74"), upright)
	for side in [-1.0, 1.0]:
		for axle in [-1.26, 1.31]:
			var wheel := Vector3(side * 0.91, 0.38, axle)
			_box(at + upright * wheel, Vector3(0.20, 0.57, 0.53), Color("#30383a"), upright)


func _clear(location: Vector3, margin: float) -> bool:
	var nearest: Dictionary = _track.project(location)
	var difference: Vector3 = location - nearest.position
	difference.y = 0.0
	return difference.length() > _track.half_width + margin


func _container(at: Vector3, color: Color, orientation: Basis) -> void:
	_box(at, Vector3(2.41, 2.43, 11.8), color, orientation)
	for side in [-1.0, 1.0]:
		for row in [-0.97, 0.96]:
			_box(at + orientation.x * side * 1.220 + Vector3.UP * row, Vector3(0.055, 0.11, 11.72), color.darkened(0.24), orientation)
		if _quality != 0:
			for rib in range(6):
				var at_rib: Vector3 = at + orientation.x * side * 1.219 + orientation.z * (-4.85 + rib * 1.93)
				_box(at_rib, Vector3(0.086, 2.06, 0.16), color.lightened(0.16), orientation)
	_box(at - orientation.z * 5.91, Vector3(1.87, 1.88, 0.06), color.darkened(0.25), orientation)
	_box(at - orientation.z * 5.96, Vector3(0.12, 1.77, 0.07), Color("#7a8180"), orientation)


func _warehouse(at: Vector3, number: int, color: Color) -> void:
	var facade := color.lightened((number % 3) * 0.13)
	_box(at + Vector3.UP * 4.4, Vector3(19, 9.0, 34), facade)
	_box(at + Vector3.UP * 9.08, Vector3(20.2, 0.59, 35), color.darkened(0.24))
	_box(at + Vector3(-9.56, 2.13, 0), Vector3(0.10, 4.2, 8.5), Color("#313e46"))
	_box(at + Vector3(-9.59, 4.29, 0), Vector3(0.12, 0.12, 8.5), ORANGE, Basis.IDENTITY, true)
	for left in range(3):
		var d := -11.2 + left * 10.0
		_box(at + Vector3(-9.54, 6.37, d), Vector3(0.065, 1.25, 5.2), Color("#80939e"))
	_box(at + Vector3(-5.8, 9.72, 8.25), Vector3(2.2, 1.3, 3.25), color.lightened(0.25))


func _dock_crane(at: Vector3, index: int) -> void:
	var metal := Color("#665a5d").lightened(index * 0.05)
	for z in [-5.4, 5.4]:
		for x in [-4.8, 4.8]:
			_box(at + Vector3(x, 10.6, z), Vector3(0.82, 21.4, 0.89), metal)
			_box(at + Vector3(x, 0.27, z), Vector3(1.73, 0.55, 1.67), Color("#484f58"))
		_box(at + Vector3(-10.1, 21.04, z), Vector3(35, 1.36, 0.80), metal)
		_box(at + Vector3(-17.8, 28.1, z), Vector3(14.8, 0.76, 0.63), metal, Basis(Vector3.FORWARD, -0.55))
		_box(at + Vector3(-27.27, 16.16, z), Vector3(0.08, 9, 0.09), Color("#3a4554"))
	_box(at + Vector3(-28, 11.9, 0), Vector3(2.8, 0.55, 12.2), metal.lightened(0.16))
	_box(at + Vector3(4.9, 21.82, 0), Vector3(0.60, 0.47, 12.3), ORANGE, Basis.IDENTITY, true)


func _mountains() -> void:
	_rails(9 if _quality != 0 else 17, Color("#a5a5a0"), false)
	_road_sign(47.0, 1.0, "BR-63", Color("#d0d5c3"))
	_road_sign(_track.length * 0.45, 1.0, "KM 04", Color("#d0d5c3"))
	_sponsor(83.0, -1.0, "SERRA DA LUA", "RESERVA DO ALTO", Color("#e9be88"))
	var mountain_color := Color("#857780")
	var bounds: Rect2 = _track.bounds()
	var world_center := Vector3(bounds.get_center().x, 0, -bounds.get_center().y)
	for i in range(22 if _quality == 0 else 40):
		var angle := i * 0.26 + _rng.randf_range(-0.04, 0.04)
		var radius := maxf(bounds.size.x, bounds.size.y) * 0.63 + _rng.randf_range(69.0, 226.0)
		var at := world_center + Vector3(cos(angle) * radius, -29.0, sin(angle) * radius)
		var dimensions := Vector3(_rng.randf_range(100, 275), _rng.randf_range(68, 159), _rng.randf_range(88, 260))
		_prop("peak", at, dimensions, mountain_color.lightened(_rng.randf_range(-0.23, 0.16)), Basis(Vector3.UP, angle))
	var stride := 26 if _quality == 0 else 15
	for distance in range(3, int(_track.length), stride):
		var frame := _frame(distance)
		var p: Vector3 = frame.position
		var right: Vector3 = frame.right
		var steep: float = absf(frame.curvature)
		for side in [-1.0, 1.0]:
			var count := 2 if _quality == 0 else 4
			for i in count:
				var offset: float = side * _rng.randf_range(_track.half_width + 4.2, _track.half_width + 16.0)
				var wave: float = _rng.randf_range(-6.0, 6.0)
				var location: Vector3 = p + right * offset + frame.forward * wave
				var basis := Basis(Vector3.UP, _rng.randf() * TAU)
				var height := _rng.randf_range(1.8, 5.1)
				var correction := clampf((absf(offset) - _track.half_width) * 0.17, 0.5, 3.0)
				if i == 0 or _rng.randf() > 0.57:
					location.y += height * 0.32 - correction
					_prop("stone", location, Vector3(height * 1.18, height * 0.69, height * 0.95), Color("#92776b").lightened(_rng.randf_range(-0.22, 0.20)), basis)
				else:
					location.y += height * 0.49 - correction
					_prop("tree", location, Vector3(height * 0.63, height * 0.97, height * 0.69), Color("#63766c").lightened(_rng.randf_range(-0.21, 0.14)), basis)
					_box(location - Vector3.UP * height * 0.43, Vector3(0.13, height * 0.61, 0.13), Color("#635c54"), basis)
		if steep > 0.017:
			_chevron(distance, signf(frame.curvature))


func _chevron(distance: float, side: float) -> void:
	var frame := _frame(distance)
	var basis := _basis(frame)
	var base: Vector3 = frame.position + frame.right * side * (_track.half_width + 2.4)
	_box(base + Vector3.UP * 0.68, Vector3(0.10, 1.45, 0.09), Color("#8a8a75"), basis)
	_box(base + Vector3.UP * 1.33, Vector3(0.94, 0.72, 0.13), Color("#e6b44f"), basis)
	_label("›" if side < 0.0 else "‹", base + Vector3.UP * 1.39 - frame.forward * 0.08, basis, 0.020, Color("#46362d"))


func _rails(spacing: int, shade: Color, both: bool) -> void:
	for distance in range(1, int(_track.length - spacing), spacing):
		var frame := _frame(distance)
		var next := _frame(distance + spacing - 0.20)
		for side in [-1.0, 1.0]:
			if not both and side > 0.0 and (distance / spacing) % 7 > 2:
				continue
			if both and distance > 96 and (distance / spacing) % 11 > 5:
				continue
			var setback: float = side * (_track.half_width + 1.75)
			var a: Vector3 = frame.position + frame.right * setback + Vector3.UP * 0.47
			var b: Vector3 = next.position + next.right * setback + Vector3.UP * 0.47
			var length := a.distance_to(b)
			var axis := (a - b).normalized()
			var right := Vector3.UP.cross(axis).normalized()
			var basis := Basis(right, axis.cross(right).normalized(), axis)
			_box((a + b) * 0.5, Vector3(0.12, 0.28, length + 0.05), shade, basis)
			_box(a - Vector3.UP * 0.04, Vector3(0.14, 1.13, 0.16), shade.darkened(0.43), basis)


func _floodlight(distance: float, side: float, accent: Color, docks := false) -> void:
	var frame := _frame(distance)
	var base: Vector3 = frame.position + frame.right * side * (_track.half_width + (3.4 if docks else 7.4))
	var upright := _basis(frame)
	var h := 6.3 if docks else 11.2
	_box(base + Vector3.UP * (h * 0.50), Vector3(0.13, h, 0.13), Color("#657178"), upright)
	_box(base + Vector3.UP * h - frame.right * side * 0.65, Vector3(1.45, 0.14, 0.20), Color("#57626a"), upright)
	for i in 2 if docks else 4:
		var at: Vector3 = base + Vector3.UP * h - frame.right * side * (0.18 + i * 0.35) - frame.forward * 0.10
		_box(at, Vector3(0.28, 0.14, 0.20), accent, upright, true)
	if docks:
		var at: Vector3 = frame.position + frame.right * side * (_track.half_width - 1.4) + Vector3.UP * 0.017
		_prop("spill", at, Vector3(12.8, 1.0, 14.0), accent.darkened(0.22), upright)


func _sponsor(distance: float, side: float, title: String, subtitle: String, accent: Color) -> void:
	var frame := _frame(distance)
	var upright := _basis(frame)
	var base: Vector3 = frame.position + frame.right * side * (_track.half_width + 7.2)
	for x in [-2.62, 2.62]:
		_box(base + frame.right * x + Vector3.UP * 1.28, Vector3(0.17, 2.75, 0.18), Color("#849595"), upright)
	_box(base + Vector3.UP * 2.93, Vector3(7.4, 2.32, 0.26), Color("#34434a"), upright)
	_box(base + Vector3.UP * 4.13, Vector3(7.45, 0.18, 0.29), accent, upright)
	_label(title, base + Vector3.UP * 3.23 - frame.forward * 0.15, upright, 0.020, WHITE)
	_label(subtitle, base + Vector3.UP * 2.39 - frame.forward * 0.17, upright, 0.0085, accent)


func _basis(frame: Dictionary) -> Basis:
	var right: Vector3 = frame.right
	return Basis(right, Vector3.UP, right.cross(Vector3.UP)).orthonormalized()


func _place_surface(title: String, surface: Surface, roughness: float) -> void:
	if surface.vertices.is_empty():
		return
	var shape := MeshInstance3D.new()
	shape.name = title
	shape.mesh = surface.make_mesh(roughness)
	if title != "Terreno" and title != "Asfalto":
		shape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shape)


func _label(text: String, at: Vector3, orientation: Basis, pixels: float, shade: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.basis = orientation
	label.font_size = 62
	label.pixel_size = pixels
	label.modulate = shade
	label.outline_size = 6
	label.outline_modulate = Color("#263238")
	label.double_sided = false
	label.visibility_range_end = 150.0
	add_child(label)


func _box(at: Vector3, dimensions: Vector3, shade: Color, orientation := Basis.IDENTITY, emissive := false) -> void:
	_prop("glow" if emissive else "box", at, dimensions, shade, orientation)


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
			if key in ["glow", "spill", "peak"] or _quality != 2:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)
	_batches.clear()


func _get_prop_mesh(key: String) -> Mesh:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	if key == "spill":
		return _light_spill()
	if key == "tree":
		var tree := CylinderMesh.new()
		tree.top_radius = 0.05
		tree.bottom_radius = 0.5
		tree.height = 1.0
		tree.radial_segments = 6
		tree.rings = 1
		tree.material = material
		return tree
	if key == "peak" or key == "stone":
		var stone := SphereMesh.new()
		stone.radius = 0.5
		stone.height = 1.0
		stone.radial_segments = 6 if key == "peak" else 5
		stone.rings = 3
		stone.material = material
		return stone
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
