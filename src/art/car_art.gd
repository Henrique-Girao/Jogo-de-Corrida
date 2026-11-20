extends RefCounted
## Interpret the authored GLB coachwork and animate the wheels and brake lights.

const Models = preload("res://src/art/model_library.gd")
const FINISH = preload("res://src/art/shaders/finish.gdshader")
const ATLAS_DIR := "res://assets/models/cars/atlas/"
const TRIM = preload("res://assets/models/cars/atlas/coach_trim.png")
const PROFILES := {
	"brasa_16": { "size": Vector3(1.67, 1.39, 3.68), "wheel": Vector2(0.285, 0.175), "axles": Vector2(-0.31, 0.3), "paint": "#d14836", "sheen": 0.45 },
	"linha_rs": { "size": Vector3(1.75, 1.43, 3.95), "wheel": Vector2(0.302, 0.192), "axles": Vector2(-0.31, 0.31), "paint": "#eaa832", "sheen": 0.54 },
	"monte_gt": { "size": Vector3(1.81, 1.42, 4.56), "wheel": Vector2(0.313, 0.207), "axles": Vector2(-0.31, 0.31), "paint": "#5f8b84", "sheen": 0.57 },
	"vetra_x": { "size": Vector3(1.85, 1.39, 4.17), "wheel": Vector2(0.32, 0.225), "axles": Vector2(-0.3, 0.318), "paint": "#a3b845", "sheen": 0.54 },
	"fenda_30": { "size": Vector3(1.84, 1.25, 4.25), "wheel": Vector2(0.306, 0.219), "axles": Vector2(-0.297, 0.31), "paint": "#6a86bc", "sheen": 0.58 },
	"trovao_68": { "size": Vector3(1.97, 1.34, 4.75), "wheel": Vector2(0.345, 0.248), "axles": Vector2(-0.32, 0.31), "paint": "#bd682d", "sheen": 0.51 },
	"iris_22": { "size": Vector3(1.89, 1.31, 4.46), "wheel": Vector2(0.321, 0.234), "axles": Vector2(-0.308, 0.307), "paint": "#665d8e", "sheen": 0.59 },
	"alvor_72": { "size": Vector3(1.73, 1.23, 4.18), "wheel": Vector2(0.29, 0.188), "axles": Vector2(-0.295, 0.31), "paint": "#ddc58c", "sheen": 0.57 },
	"vektor_v8": { "size": Vector3(1.95, 1.26, 4.49), "wheel": Vector2(0.334, 0.247), "axles": Vector2(-0.314, 0.31), "paint": "#8e9da4", "sheen": 0.62 },
	"miragem_r": { "size": Vector3(2.02, 1.16, 4.58), "wheel": Vector2(0.343, 0.269), "axles": Vector2(-0.31, 0.31), "paint": "#b73b51", "sheen": 0.64 },
	"furgao_servico": { "size": Vector3(1.82, 1.92, 4.08), "wheel": Vector2(0.300, 0.180), "axles": Vector2(-0.298, 0.329), "paint": "#a8a59a", "sheen": 0.41 },
}
static var _glazing: Dictionary = {}


static func create(spec: Dictionary, quality: int = 1, parked: bool = false) -> Node3D:
	var id := _model_id(spec)
	var profile: Dictionary = PROFILES[id]
	var assets := Models.meshes("res://assets/models/cars/%s.glb" % id)
	var car := Node3D.new()
	car.name = "Carro"
	var body := _instance(assets["Carroceria_" + id])
	body.name = "Carroceria"
	car.add_child(body)

	var tint := _color(spec.get("color", profile.paint), Color(profile.paint))
	var tail: StandardMaterial3D
	for slot in body.mesh.get_surface_count():
		var original := body.mesh.surface_get_material(slot) as StandardMaterial3D
		var label := original.resource_name
		if original.albedo_texture == null:
			# The standalone GLB has its own materials. The game shares one atlas for trim and wheels.
			original.albedo_texture = load(ATLAS_DIR + "finish_%s.png" % id) if label.begins_with("Pintura") else TRIM
		if label.begins_with("Pintura"):
			var paint := _finish(tint, 0.49 - float(profile.sheen) * 0.34, profile.sheen, original.albedo_texture)
			body.set_surface_override_material(slot, paint)
			car.set_meta("paint_slot", slot)
		elif label.begins_with("Vidro"):
			if not _glazing.has(id):
				_glazing[id] = _finish(Color.WHITE, 0.34, 0.63, original.albedo_texture, 1.0)
			body.set_surface_override_material(slot, _glazing[id])
		elif label.begins_with("Lanternas"):
			tail = original.duplicate() as StandardMaterial3D
			tail.emission_enabled = true
			tail.emission = Color("#ff283f")
			tail.emission_energy_multiplier = 0.17
			body.set_surface_override_material(slot, tail)
		elif label.begins_with("Farois") and quality > 0:
			var headlight := original.duplicate() as StandardMaterial3D
			headlight.emission_enabled = true
			headlight.emission = Color("#fff0c2")
			headlight.emission_energy_multiplier = 0.13
			body.set_surface_override_material(slot, headlight)

	var wheel_mesh: Mesh = assets["Roda_" + id]
	var wheel_finish := wheel_mesh.surface_get_material(0) as StandardMaterial3D
	wheel_finish.albedo_texture = TRIM
	var size: Vector3 = profile.size
	var wheel: Vector2 = profile.wheel
	var axles: Vector2 = profile.axles
	var front: Array[Node3D] = []
	var rollers: Array[Node3D] = []
	var tires: MultiMesh
	if parked:
		tires = MultiMesh.new()
		tires.transform_format = MultiMesh.TRANSFORM_3D
		tires.mesh = wheel_mesh
		tires.instance_count = 4
	var wheel_index := 0
	for axle in [axles.x, axles.y]:
		for side in [-1.0, 1.0]:
			var center := Vector3(side * (size.x * 0.485 - wheel.y * 0.45), wheel.x, axle * size.z)
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
			var rim := _instance(wheel_mesh)
			rim.rotation.y = heading
			roller.add_child(rim)
			rollers.append(roller)
			if axle < 0.0:
				front.append(mount)
	if parked:
		var wheels := MultiMeshInstance3D.new()
		wheels.multimesh = tires
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
	_paint_finish(car).set_shader_parameter("tint", tint)


static func paint_tint(car: Node3D) -> Color:
	return _paint_finish(car).get_shader_parameter("tint")


static func _paint_finish(car: Node3D) -> ShaderMaterial:
	var body := car.get_meta("body") as MeshInstance3D
	return body.get_surface_override_material(int(car.get_meta("paint_slot"))) as ShaderMaterial


static func _finish(tint: Color, roughness: float, sheen: float, sheet: Texture2D, glass: float = 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FINISH
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("coat_roughness", roughness)
	material.set_shader_parameter("sheen", sheen)
	material.set_shader_parameter("panel_map", sheet)
	material.set_shader_parameter("glass", glass)
	return material


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
	if brake != car.get_meta("brake") and car.get_meta("tail") != null:
		var tail: StandardMaterial3D = car.get_meta("tail")
		tail.emission_energy_multiplier = 1.45 if brake else 0.17
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
