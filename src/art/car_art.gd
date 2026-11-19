extends RefCounted
## Catálogo de carrocerias procedurais. O eixo dianteiro aponta para -Z.

const PROFILES := {
	"brasa_16": {
		"size": Vector3(1.67, 1.39, 3.68), "wheel": Vector2(0.285, 0.175),
		"axles": Vector2(-0.31, 0.30), "cabin": Vector4(-0.28, -0.09, 0.29, 0.44),
		"deck": [0.63, 0.70, 0.74, 0.75, 0.75, 0.77, 0.80, 0.77, 0.73],
		"width": [0.87, 0.95, 1.0, 0.97, 0.97, 0.99, 1.0, 0.95, 0.86],
		"roof_width": 0.76, "spokes": 6, "front": "quad", "rear": "stack",
		"paint": "#d14836"
	},
	"linha_rs": {
		"size": Vector3(1.75, 1.43, 3.95), "wheel": Vector2(0.302, 0.192),
		"axles": Vector2(-0.31, 0.31), "cabin": Vector4(-0.29, -0.10, 0.23, 0.43),
		"deck": [0.61, 0.69, 0.77, 0.80, 0.81, 0.84, 0.85, 0.80, 0.73],
		"width": [0.76, 0.91, 1.0, 0.98, 0.97, 0.99, 1.0, 0.93, 0.79],
		"roof_width": 0.71, "spokes": 8, "front": "slash", "rear": "angle",
		"paint": "#eaa832"
	},
	"monte_gt": {
		"size": Vector3(1.81, 1.42, 4.56), "wheel": Vector2(0.313, 0.207),
		"axles": Vector2(-0.31, 0.31), "cabin": Vector4(-0.23, -0.074, 0.185, 0.344),
		"deck": [0.62, 0.71, 0.77, 0.80, 0.81, 0.80, 0.83, 0.82, 0.76],
		"width": [0.78, 0.91, 1.0, 0.97, 0.96, 0.97, 1.0, 0.93, 0.82],
		"roof_width": 0.76, "spokes": 7, "front": "bar", "rear": "bar",
		"paint": "#5f8b84"
	},
	"vetra_x": {
		"size": Vector3(1.85, 1.39, 4.17), "wheel": Vector2(0.32, 0.225),
		"axles": Vector2(-0.30, 0.318), "cabin": Vector4(-0.29, -0.09, 0.25, 0.45),
		"deck": [0.58, 0.70, 0.78, 0.81, 0.84, 0.87, 0.87, 0.81, 0.74],
		"width": [0.81, 0.97, 1.0, 0.95, 0.93, 0.98, 1.02, 0.94, 0.84],
		"roof_width": 0.71, "spokes": 5, "front": "split", "rear": "angle",
		"paint": "#a3b845"
	},
	"fenda_30": {
		"size": Vector3(1.84, 1.25, 4.25), "wheel": Vector2(0.306, 0.219),
		"axles": Vector2(-0.297, 0.31), "cabin": Vector4(-0.206, -0.08, 0.11, 0.354),
		"deck": [0.49, 0.55, 0.65, 0.71, 0.74, 0.76, 0.74, 0.71, 0.68],
		"width": [0.81, 0.93, 1.0, 0.96, 0.94, 0.96, 1.02, 0.97, 0.87],
		"roof_width": 0.67, "spokes": 5, "front": "pop", "rear": "bar",
		"paint": "#6a86bc"
	},
	"trovao_68": {
		"size": Vector3(1.97, 1.34, 4.75), "wheel": Vector2(0.345, 0.248),
		"axles": Vector2(-0.32, 0.31), "cabin": Vector4(-0.13, -0.02, 0.173, 0.36),
		"deck": [0.69, 0.77, 0.81, 0.81, 0.79, 0.82, 0.86, 0.83, 0.73],
		"width": [0.89, 0.98, 1.0, 0.98, 0.94, 0.97, 1.03, 0.98, 0.86],
		"roof_width": 0.72, "spokes": 5, "front": "round", "rear": "stack",
		"paint": "#bd682d"
	},
	"iris_22": {
		"size": Vector3(1.89, 1.31, 4.46), "wheel": Vector2(0.321, 0.234),
		"axles": Vector2(-0.308, 0.307), "cabin": Vector4(-0.197, -0.086, 0.167, 0.344),
		"deck": [0.57, 0.65, 0.73, 0.76, 0.78, 0.81, 0.85, 0.79, 0.73],
		"width": [0.85, 0.97, 1.0, 0.96, 0.94, 0.98, 1.04, 0.98, 0.87],
		"roof_width": 0.68, "spokes": 6, "front": "split", "rear": "round",
		"paint": "#665d8e"
	},
	"alvor_72": {
		"size": Vector3(1.73, 1.23, 4.18), "wheel": Vector2(0.29, 0.188),
		"axles": Vector2(-0.295, 0.31), "cabin": Vector4(-0.18, -0.045, 0.137, 0.345),
		"deck": [0.50, 0.54, 0.65, 0.70, 0.74, 0.77, 0.75, 0.65, 0.57],
		"width": [0.69, 0.88, 1.02, 0.98, 0.91, 0.99, 1.01, 0.91, 0.78],
		"roof_width": 0.62, "spokes": 4, "front": "orb", "rear": "round",
		"paint": "#ddc58c"
	},
	"vektor_v8": {
		"size": Vector3(1.95, 1.26, 4.49), "wheel": Vector2(0.334, 0.247),
		"axles": Vector2(-0.314, 0.31), "cabin": Vector4(-0.15, -0.038, 0.178, 0.371),
		"deck": [0.54, 0.64, 0.74, 0.81, 0.83, 0.83, 0.86, 0.78, 0.71],
		"width": [0.80, 0.96, 1.02, 0.98, 0.93, 0.99, 1.04, 0.98, 0.86],
		"roof_width": 0.67, "spokes": 10, "front": "slash", "rear": "bar",
		"paint": "#8e9da4"
	},
	"miragem_r": {
		"size": Vector3(2.02, 1.16, 4.58), "wheel": Vector2(0.343, 0.269),
		"axles": Vector2(-0.31, 0.31), "cabin": Vector4(-0.254, -0.096, 0.15, 0.382),
		"deck": [0.47, 0.55, 0.65, 0.72, 0.75, 0.77, 0.83, 0.75, 0.65],
		"width": [0.82, 0.97, 1.03, 0.97, 0.89, 0.98, 1.06, 0.99, 0.88],
		"roof_width": 0.63, "spokes": 7, "front": "split", "rear": "bar",
		"paint": "#b73b51"
	}
}

const STATIONS := [-0.5, -0.46, -0.33, -0.17, 0.02, 0.20, 0.35, 0.46, 0.5]
const INK := Color("#1b2229")
const GRILLE := Color("#0e141a")
const RUBBER := Color("#242a31")
const METAL := Color("#a5abb4")
const WINDOW := Color("#233442")
const WINDOW_TOP := Color("#354e5d")
const HEAD := Color("#fff0be")
const REAR := Color("#ff344c")

static var _body_cache: Dictionary = {}
static var _wheel_cache: Dictionary = {}
static var _trim_mat: StandardMaterial3D
static var _glass_mat: StandardMaterial3D
static var _wheel_mat: StandardMaterial3D
static var _head_mat: StandardMaterial3D


static func create(spec: Dictionary, quality: int = 1, parked: bool = false) -> Node3D:
	var model := _model_id(spec)
	var profile: Dictionary = PROFILES[model]
	var color := _color(spec.get("color", profile.paint), Color(profile.paint))
	var detail := int(quality > 0)
	var key := "%s:%d" % [model, detail]
	if not _body_cache.has(key):
		_body_cache[key] = _make_body(profile, detail)
	if not _wheel_cache.has(key):
		_wheel_cache[key] = _make_wheel(profile, detail)
	if _trim_mat == null:
		_trim_mat = _material(Color.WHITE, 0.75, 0.14)
		_glass_mat = _material(Color.WHITE, 0.24, 0.29)
		_wheel_mat = _material(Color.WHITE, 0.67, 0.22)
		_head_mat = _material(Color.WHITE, 0.25, 0.05, HEAD, 0.40)

	var car := Node3D.new()
	car.name = "Carro"
	var paint := _material(color, 0.36, 0.24)
	var tail := _material(Color.WHITE, 0.30, 0.03, REAR, 0.18)
	var body := _instance(_body_cache[key])
	body.name = "Carroceria"
	var materials := [paint, _trim_mat, _glass_mat, _head_mat, tail]
	for i in materials.size():
		body.set_surface_override_material(i, materials[i])
	car.add_child(body)

	var size: Vector3 = profile.size
	var wheel: Vector2 = profile.wheel
	var axles: Vector2 = profile.axles
	var front: Array[Node3D] = []
	var rollers: Array[Node3D] = []
	var tires: MultiMesh
	if parked:
		tires = MultiMesh.new()
		tires.transform_format = MultiMesh.TRANSFORM_3D
		tires.mesh = _wheel_cache[key]
		tires.instance_count = 4
	var wheel_index := 0
	for axle in [axles.x, axles.y]:
		for side in [-1.0, 1.0]:
			var center := Vector3(side * (size.x * 0.492 - wheel.y * 0.25), wheel.x, axle * size.z)
			var heading := PI if side < 0.0 else 0.0
			if parked:
				tires.set_instance_transform(wheel_index, Transform3D(Basis(Vector3.UP, heading), center))
				wheel_index += 1
				continue
			var mount := Node3D.new()
			mount.position = center
			car.add_child(mount)
			var roller := Node3D.new()
			mount.add_child(roller)
			var rim := _instance(_wheel_cache[key])
			rim.material_override = _wheel_mat
			rim.rotation.y = heading
			roller.add_child(rim)
			rollers.append(roller)
			if axle < 0.0:
				front.append(mount)
	if parked:
		var wheels := MultiMeshInstance3D.new()
		wheels.multimesh = tires
		wheels.material_override = _wheel_mat
		car.add_child(wheels)
	car.set_meta("front", front)
	car.set_meta("rollers", rollers)
	car.set_meta("radius", wheel.x)
	car.set_meta("body", body)
	car.set_meta("tail", tail)
	car.set_meta("brake", false)
	return car


static func dimensions(spec: Dictionary) -> Vector3:
	return PROFILES[_model_id(spec)].size


static func set_paint(car: Node3D, tint: Color) -> void:
	var body := car.get_meta("body") as MeshInstance3D
	var paint := body.get_surface_override_material(0) as StandardMaterial3D
	paint.albedo_color = tint


static func _model_id(spec: Dictionary) -> String:
	var model := str(spec.get("model", spec.get("id", "brasa_16")))
	return model if PROFILES.has(model) else "brasa_16"


static func set_motion(car: Node3D, speed: float, steer: float, brake: bool, delta: float) -> void:
	if car == null or not car.has_meta("rollers"):
		return
	for mount: Node3D in car.get_meta("front"):
		mount.rotation.y = lerpf(mount.rotation.y, -steer * 0.45, minf(delta * 13.0, 1.0))
	var radius: float = car.get_meta("radius")
	for roller: Node3D in car.get_meta("rollers"):
		roller.rotation.x = wrapf(roller.rotation.x - speed * delta / radius, -PI, PI)
	if brake != car.get_meta("brake"):
		var tail: StandardMaterial3D = car.get_meta("tail")
		tail.emission_energy_multiplier = 1.85 if brake else 0.18
		car.set_meta("brake", brake)


static func set_body_lean(car: Node3D, pitch: float, roll: float, delta: float) -> void:
	var body: Node3D = car.get_meta("body")
	body.rotation.x = lerpf(body.rotation.x, pitch, minf(delta * 9.0, 1.0))
	body.rotation.z = lerpf(body.rotation.z, roll, minf(delta * 9.0, 1.0))


static func _color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return Color.from_string(str(value), fallback)


static func _instance(mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return node


static func _material(tint: Color, roughness: float, metalness: float, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	material.metallic = metalness
	material.vertex_color_use_as_albedo = true
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


static func _surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


static func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.length_squared() < 0.01:
		return
	var points: Array[Vector3] = [a, b, c]
	if normal.dot(out) > 0.0:
		points = [a, c, b]
	else:
		normal = -normal
	for point in points:
		surface.set_normal(normal)
		surface.set_color(tint)
		surface.add_vertex(point)


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, tint: Color) -> void:
	_tri(surface, a, b, c, out, tint)
	_tri(surface, a, c, d, out, tint)


static func _value(profile: Dictionary, key: String, at: float) -> float:
	var values: Array = profile[key]
	for i in range(1, STATIONS.size()):
		if at <= STATIONS[i]:
			return lerpf(values[i - 1], values[i], inverse_lerp(STATIONS[i - 1], STATIONS[i], at))
	return values.back()


static func _lower(profile: Dictionary, normalized_z: float) -> float:
	var wheel: Vector2 = profile.wheel
	var axles: Vector2 = profile.axles
	var size: Vector3 = profile.size
	var opening := wheel.x * 1.12
	var height := 0.195
	for axle in [axles.x, axles.y]:
		var distance: float = absf(normalized_z - axle) * size.z
		if distance <= opening:
			height = maxf(height, wheel.x + sqrt(maxf(opening * opening - distance * distance, 0.0)))
	return height


static func _make_body(profile: Dictionary, detail: int) -> ArrayMesh:
	var paint := _surface()
	var trim := _surface()
	var glass := _surface()
	var lights := _surface()
	var tail := _surface()
	_chassis(profile, paint, trim, detail)
	_cockpit(profile, paint, trim, glass, detail)
	_fascias(profile, trim, lights, tail, detail)
	var mesh := ArrayMesh.new()
	for surface: SurfaceTool in [paint, trim, glass, lights, tail]:
		surface.index()
		surface.commit(mesh)
	return mesh


static func _chassis(profile: Dictionary, paint: SurfaceTool, trim: SurfaceTool, detail: int) -> void:
	var size: Vector3 = profile.size
	var wheel: Vector2 = profile.wheel
	var axles: Vector2 = profile.axles
	var outline: Array[float] = []
	outline.assign(STATIONS)
	var opening := wheel.x * 1.12 / size.z
	var resolution := 10 if detail > 0 else 7
	for axle in [axles.x, axles.y]:
		outline.append(axle - opening - 0.0015)
		outline.append(axle + opening + 0.0015)
		for step in range(resolution + 1):
			outline.append(axle - cos(float(step) * PI / resolution) * opening)
	outline.sort()
	for i in range(outline.size() - 1):
		var z0 := outline[i]
		var z1 := outline[i + 1]
		var width0 := _value(profile, "width", z0) * size.x * 0.5
		var width1 := _value(profile, "width", z1) * size.x * 0.5
		var top0 := _value(profile, "deck", z0)
		var top1 := _value(profile, "deck", z1)
		var bottom0 := minf(_lower(profile, z0), top0 - 0.035)
		var bottom1 := minf(_lower(profile, z1), top1 - 0.035)
		var belt0 := maxf(top0 - 0.13, bottom0 + 0.018)
		var belt1 := maxf(top1 - 0.13, bottom1 + 0.018)
		var actual0 := z0 * size.z
		var actual1 := z1 * size.z
		for side in [-1.0, 1.0]:
			var a := Vector3(side * width0 * 0.97, top0, actual0)
			var b := Vector3(side * width1 * 0.97, top1, actual1)
			var c := Vector3(side * width0, belt0, actual0)
			var d := Vector3(side * width1, belt1, actual1)
			var e := Vector3(side * width0 * 0.94, bottom0, actual0)
			var f := Vector3(side * width1 * 0.94, bottom1, actual1)
			var outward := Vector3(side, 0, 0)
			_quad(paint, a, b, d, c, outward, Color("#e5e7e9"))
			_quad(paint, c, d, f, e, outward, Color("#a3a9ad"))
			_quad(paint, a, Vector3(0, top0 + 0.049, actual0), Vector3(0, top1 + 0.049, actual1), b, Vector3.UP, Color.WHITE)
			if detail > 0 and (bottom0 > 0.24 or bottom1 > 0.24):
				_quad(trim, e, f, f - outward * 0.055, e - outward * 0.055, Vector3.DOWN, INK)
	for end in [-1.0, 1.0]:
		var at: float = end * 0.5
		var w := _value(profile, "width", at) * size.x * 0.5
		var top := _value(profile, "deck", at)
		var z := at * size.z
		var out := Vector3(0.0, 0.0, end)
		var mid := Vector3(0.0, top + 0.049, z)
		for side in [-1.0, 1.0]:
			_quad(paint, mid, Vector3(side * w * 0.97, top, z), Vector3(side * w, top - 0.13, z), Vector3(0, top - 0.13, z), out, Color("#e6e7eb"))
			_quad(paint, Vector3(0, top - 0.13, z), Vector3(side * w, top - 0.13, z), Vector3(side * w * 0.94, 0.195, z), Vector3(0, 0.195, z), out, Color("#c5c9ce"))
	_box(trim, Vector3(0, 0.213, 0), Vector3(size.x * 0.60, 0.17, size.z * 0.91), GRILLE)
	if detail > 0:
		for side in [-1.0, 1.0]:
			_box(trim, Vector3(side * size.x * 0.463, 0.228, 0), Vector3(0.055, 0.077, size.z * 0.40), INK)
			var handle_z := size.z * 0.065
			var handle_height := _value(profile, "deck", 0.065) - 0.055
			var handle_x := _value(profile, "width", 0.065) * size.x * 0.484
			_box(trim, Vector3(side * handle_x, handle_height, handle_z), Vector3(0.025, 0.025, 0.112), INK)


static func _cockpit(profile: Dictionary, paint: SurfaceTool, trim: SurfaceTool, glass: SurfaceTool, detail: int) -> void:
	var size: Vector3 = profile.size
	var cabin: Vector4 = profile.cabin
	var roof_width: float = profile.roof_width
	var sections: Array[Vector3] = [
		Vector3(_value(profile, "width", cabin.x) * size.x * 0.43, _value(profile, "deck", cabin.x) + 0.034, cabin.x * size.z),
		Vector3(size.x * roof_width * 0.5, size.y - 0.044, cabin.y * size.z),
		Vector3(size.x * roof_width * 0.49, size.y - 0.056, cabin.z * size.z),
		Vector3(_value(profile, "width", cabin.w) * size.x * 0.435, _value(profile, "deck", cabin.w) + 0.036, cabin.w * size.z)
	]
	var front := sections[0]
	var brow := sections[1]
	var crown := sections[2]
	var back := sections[3]
	_inset(glass, paint, _mirror(front), front, brow, _mirror(brow), Vector3(0.0, 0.7, -0.7), WINDOW, 0.067, 0.07)
	_inset(glass, paint, _mirror(crown), crown, back, _mirror(back), Vector3(0.0, 0.6, 0.8), WINDOW, 0.082, 0.081)
	for side in [-1.0, 1.0]:
		var lower_front := Vector3(side * front.x, front.y, front.z)
		var upper_front := Vector3(side * brow.x, brow.y, brow.z)
		var upper_back := Vector3(side * crown.x, crown.y, crown.z)
		var lower_back := Vector3(side * back.x, back.y, back.z)
		var crest_front := Vector3(0, brow.y + 0.044, brow.z)
		var crest_back := Vector3(0, crown.y + 0.050, crown.z)
		var out := Vector3(side, 0.25, 0.0)
		_quad(paint, upper_front, crest_front, crest_back, upper_back, Vector3.UP, Color.WHITE)
		_inset(glass, paint, lower_front, lower_back, upper_back, upper_front, out, WINDOW_TOP, 0.063, 0.095)
		var pillar_low := lower_front.lerp(lower_back, 0.53)
		var pillar_high := upper_front.lerp(upper_back, 0.53)
		var offset := Vector3(side * 0.006, 0.005, 0.0)
		var half := 0.026 if profile.front == "orb" else 0.036
		_quad(trim, pillar_low + offset - Vector3(0, 0, half), pillar_low + offset + Vector3(0, 0, half), pillar_high + offset + Vector3(0, 0, half), pillar_high + offset - Vector3(0, 0, half), out, INK)

		var mirror_pos := lower_front + Vector3(side * 0.07, 0.072, size.z * 0.048)
		_box(trim, mirror_pos, Vector3(0.19, 0.055, 0.085), INK)
		_box(paint, mirror_pos + Vector3(side * 0.047, 0.032, -0.01), Vector3(0.116, 0.058, 0.16), Color("#ededed"))
		if detail > 0:
			_box(trim, mirror_pos + Vector3(side * 0.047, 0.035, 0.073), Vector3(0.091, 0.042, 0.008), Color("#778d9b"))

		if profile.rear == "round" and profile.front == "split":
			_box(paint, Vector3(side * size.x * 0.326, back.y + 0.060, size.z * 0.438), Vector3(0.095, 0.14, 0.09), Color("#dee0e3"))
		elif profile.front == "split" and profile.rear == "bar":
			var scoop := Vector3(side * size.x * 0.462, 0.52, size.z * 0.213)
			_quad(trim, scoop + Vector3(0, -0.09, -0.29), scoop + Vector3(side * 0.012, -0.07, 0.24), scoop + Vector3(side * 0.022, 0.17, 0.19), scoop + Vector3(0, 0.049, -0.14), out, GRILLE)
	if profile.rear == "round" and profile.front == "split":
		_box(paint, Vector3(0, back.y + 0.135, size.z * 0.433), Vector3(size.x * 0.82, 0.05, 0.24), Color("#d9dce0"))


static func _mirror(point: Vector3) -> Vector3:
	return Vector3(-point.x, point.y, point.z)


static func _inset(glass: SurfaceTool, trim: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, tint: Color, inset_u: float, inset_v: float) -> void:
	var inner_a := a.lerp(b, inset_u).lerp(d.lerp(c, inset_u), inset_v)
	var inner_b := b.lerp(a, inset_u).lerp(c.lerp(d, inset_u), inset_v)
	var inner_c := c.lerp(d, inset_u).lerp(b.lerp(a, inset_u), inset_v)
	var inner_d := d.lerp(c, inset_u).lerp(a.lerp(b, inset_u), inset_v)
	_quad(trim, a, b, inner_b, inner_a, out, Color("#d3d7da"))
	_quad(trim, b, c, inner_c, inner_b, out, Color("#d3d7da"))
	_quad(trim, c, d, inner_d, inner_c, out, Color("#d3d7da"))
	_quad(trim, d, a, inner_a, inner_d, out, Color("#d3d7da"))
	_quad(glass, inner_a, inner_b, inner_c, inner_d, out, tint)


static func _fascias(profile: Dictionary, trim: SurfaceTool, front: SurfaceTool, rear: SurfaceTool, detail: int) -> void:
	var size: Vector3 = profile.size
	var nose := _value(profile, "deck", -0.5)
	var deck := _value(profile, "deck", 0.5)
	var front_x := _value(profile, "width", -0.5) * size.x * 0.5
	var rear_x := _value(profile, "width", 0.5) * size.x * 0.5
	var front_z := -size.z * 0.5 - 0.008
	var rear_z := size.z * 0.5 + 0.008
	var front_style: String = profile.front
	var rear_style: String = profile.rear
	var grille_width := front_x * (1.73 if front_style == "round" else 1.12)
	var grille_y := nose - (0.12 if front_style == "round" else 0.192)
	_box(trim, Vector3(0, grille_y, front_z), Vector3(grille_width, 0.122, 0.018), GRILLE)
	_box(trim, Vector3(0, 0.217, front_z + 0.054), Vector3(front_x * 1.84, 0.055, 0.135), INK)
	_box(trim, Vector3(0, 0.236, rear_z - 0.04), Vector3(rear_x * 1.80, 0.068, 0.126), INK)
	if detail > 0:
		for i in range(3):
			_box(trim, Vector3(0, grille_y - 0.038 + i * 0.038, front_z - 0.012), Vector3(grille_width * 0.89, 0.007, 0.008), Color("#4d5459"))
	if front_style == "bar":
		_box(trim, Vector3(0, nose - 0.102, front_z), Vector3(front_x * 1.66, 0.02, 0.02), METAL)
	elif front_style == "round" or front_style == "orb":
		_box(trim, Vector3(0, nose - 0.255, front_z), Vector3(front_x * 1.85, 0.035, 0.058), METAL)
	if rear_style == "bar":
		_box(trim, Vector3(0, deck - 0.085, rear_z), Vector3(rear_x * 1.82, 0.09, 0.013), GRILLE)
		_box(rear, Vector3(0, deck - 0.063, rear_z + 0.011), Vector3(rear_x * 1.71, 0.018, 0.008), REAR)
	for side in [-1.0, 1.0]:
		var front_center := Vector3(side * front_x * 0.70, nose - 0.086, front_z - 0.013)
		var rear_center := Vector3(side * rear_x * 0.72, deck - 0.096, rear_z + 0.011)
		match front_style:
			"round", "orb":
				var count := 2 if front_style == "round" else 1
				for lamp in range(count):
					var p := front_center + Vector3(side * (0.034 - lamp * 0.13), 0.0, 0.0)
					var radius := 0.076 if count == 1 else 0.051
					_disc_z(trim, p + Vector3(0, 0, 0.004), radius * 1.20, -1.0, METAL, 10)
					_disc_z(front, p, radius, -1.0, HEAD, 10)
			"slash", "split":
				_lamp_slash(trim, front_center + Vector3(0, 0.003, 0.006), side, 0.305, 0.072, -1.0, GRILLE)
				_lamp_slash(front, front_center, side, 0.279, 0.032, -1.0, HEAD)
				if front_style == "split":
					_lamp_slash(front, front_center + Vector3(side * 0.017, -0.043, 0), side, 0.204, 0.019, -1.0, HEAD)
			"pop":
				_box(trim, front_center, Vector3(0.282, 0.075, 0.019), GRILLE)
				_box(front, front_center + Vector3(0.0, -0.005, -0.016), Vector3(0.236, 0.035, 0.012), HEAD)
				if detail > 0:
					_box(trim, Vector3(front_center.x, _value(profile, "deck", -0.44) + 0.039, -size.z * 0.432), Vector3(0.275, 0.012, 0.24), INK)
			_:
				_box(trim, front_center, Vector3(0.275, 0.106, 0.019), GRILLE)
				_box(front, front_center + Vector3(side * 0.011, 0.005, -0.013), Vector3(0.221, 0.069, 0.011), HEAD)
				if front_style == "quad":
					_box(trim, front_center + Vector3(side * 0.118, 0.0, -0.017), Vector3(0.049, 0.076, 0.008), Color("#d18c36"))
		match rear_style:
			"round":
				for lamp in range(2):
					var p := rear_center + Vector3(side * (0.039 - lamp * 0.126), 0, 0)
					_disc_z(trim, p - Vector3(0, 0, 0.004), 0.067, 1.0, GRILLE, 10)
					_disc_z(rear, p, 0.052, 1.0, REAR, 10)
			"angle":
				_lamp_slash(trim, rear_center - Vector3(0, 0, 0.006), side, 0.35, 0.08, 1.0, GRILLE)
				_lamp_slash(rear, rear_center, side, 0.295, 0.036, 1.0, REAR)
			"stack":
				_box(trim, rear_center - Vector3(0, 0.013, 0.004), Vector3(0.225, 0.113, 0.016), GRILLE)
				for band in [0.0, -0.039]:
					_box(rear, rear_center + Vector3(0.0, band, 0.009), Vector3(0.195, 0.023, 0.009), REAR)
			_:
				_box(rear, rear_center - Vector3(0, 0.012, -0.005), Vector3(0.286, 0.030, 0.012), REAR)
		if detail > 0:
			var exhaust := Vector3(side * rear_x * 0.66, 0.264, rear_z + 0.010)
			_disc_z(trim, exhaust, 0.043, 1.0, METAL, 8)
			_disc_z(trim, exhaust + Vector3(0, 0, 0.003), 0.027, 1.0, GRILLE, 8)


static func _lamp_slash(surface: SurfaceTool, center: Vector3, side: float, width: float, height: float, out: float, tint: Color) -> void:
	var inner := center + Vector3(-side * width * 0.5, -height * 0.24, 0)
	var outer := center + Vector3(side * width * 0.5, height * 0.30, 0)
	var lift := Vector3(0, height, 0)
	_quad(surface, inner, outer, outer + lift * 0.47, inner + lift * 0.78, Vector3(0, 0, out), tint)


static func _disc_z(surface: SurfaceTool, center: Vector3, radius: float, out: float, tint: Color, sides: int) -> void:
	for i in sides:
		var a := TAU * i / sides
		var b := TAU * (i + 1) / sides
		_tri(surface, center, center + Vector3(cos(a), sin(a), 0) * radius, center + Vector3(cos(b), sin(b), 0) * radius, Vector3(0, 0, out), tint)


static func _box(surface: SurfaceTool, center: Vector3, dimensions: Vector3, tint: Color) -> void:
	var half := dimensions * 0.5
	for out in [Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3.LEFT, Vector3.DOWN, Vector3.FORWARD]:
		var u: Vector3 = Vector3.FORWARD if absf(out.dot(Vector3.RIGHT)) > 0.9 else Vector3.RIGHT
		var v: Vector3 = out.cross(u)
		var a: Vector3 = center + (out + u + v) * half
		var b: Vector3 = center + (out - u + v) * half
		var c: Vector3 = center + (out - u - v) * half
		var d: Vector3 = center + (out + u - v) * half
		_quad(surface, a, b, c, d, out, tint)


static func _make_wheel(profile: Dictionary, detail: int) -> ArrayMesh:
	var wheel: Vector2 = profile.wheel
	var radius := wheel.x
	var width := wheel.y
	var spokes: int = profile.spokes
	var surface := _surface()
	var sides := 20 if detail > 0 else 12
	var rings := [
		Vector2(-width * 0.50, radius * 0.89),
		Vector2(-width * 0.40, radius),
		Vector2(width * 0.38, radius),
		Vector2(width * 0.50, radius * 0.89),
		Vector2(width * 0.52, radius * 0.72)
	]
	for i in sides:
		var a := TAU * i / sides
		var b := TAU * (i + 1) / sides
		for j in range(rings.size() - 1):
			var from: Vector2 = rings[j]
			var to: Vector2 = rings[j + 1]
			var out := Vector3(0, cos((a + b) * 0.5), sin((a + b) * 0.5))
			if j >= 2:
				out += Vector3.RIGHT
			var shade := RUBBER if j != 1 else Color("#30343b")
			_quad(surface, _wheel_point(from, a), _wheel_point(from, b), _wheel_point(to, b), _wheel_point(to, a), out, shade)
		var face := width * 0.523
		var lip_a := _wheel_point(Vector2(face, radius * 0.72), a)
		var lip_b := _wheel_point(Vector2(face, radius * 0.72), b)
		var inner_a := _wheel_point(Vector2(face, radius * 0.644), a)
		var inner_b := _wheel_point(Vector2(face, radius * 0.644), b)
		_quad(surface, lip_a, lip_b, inner_b, inner_a, Vector3.RIGHT, METAL)
		_tri(surface, Vector3(face - 0.008, 0, 0), inner_a - Vector3(0.008, 0, 0), inner_b - Vector3(0.008, 0, 0), Vector3.RIGHT, GRILLE)
		_tri(surface, Vector3(-width * 0.49, 0, 0), _wheel_point(rings[0], a), _wheel_point(rings[0], b), Vector3.LEFT, INK)
		if detail > 0:
			var hub_ring := Vector2(face + 0.006, radius * 0.179)
			_tri(surface, Vector3(hub_ring.x, 0, 0), _wheel_point(hub_ring, a), _wheel_point(hub_ring, b), Vector3.RIGHT, Color("#7d848e"))
	for i in spokes:
		var angle := TAU * i / spokes
		var outer := Vector2(width * 0.528, radius * 0.647)
		var hub := Vector2(width * 0.54, radius * 0.125)
		_quad(surface, _wheel_point(outer, angle - 0.077), _wheel_point(outer, angle + 0.075), _wheel_point(hub, angle + 0.32), _wheel_point(hub, angle - 0.33), Vector3.RIGHT, Color("#bec1c7"))
	return surface.commit()


static func _wheel_point(ring: Vector2, angle: float) -> Vector3:
	return Vector3(ring.x, cos(angle) * ring.y, sin(angle) * ring.y)
