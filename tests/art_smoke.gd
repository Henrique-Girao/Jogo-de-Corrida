extends SceneTree
## Checks the imported assets at the same entry points used in the game.

const Cars = preload("res://src/art/car_art.gd")
const Cast = preload("res://src/world/person_art.gd")
const Catalog = preload("res://src/domain/catalog.gd")
const Models = preload("res://src/art/model_library.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(Cast.CAST == Catalog.NPCS.keys(), "ordem do elenco coincide com o catálogo")
	for id in Cars.PROFILES:
		_car(id)
	for i in Cast.CAST.size() + 1:
		_actor(i)
	var scenery := Models.meshes(Models.DISTRICT_ASSETS)
	for id in scenery:
		_mesh(Models.prop(id), id)
	_check(scenery.size() == 19, "acervo de objetos disponível após importação")
	if _failures == 0:
		print("ART SMOKE OK | 11 veículos, 13 personagens e 19 modelos de cenário")
	quit(_failures)


func _car(id: String) -> void:
	var car := Cars.create({"model": id}, 1, false)
	_mesh(car.get_meta("body").mesh, id + " carroceria")
	for roller: Node3D in car.get_meta("rollers"):
		_mesh(roller.get_child(0).mesh, id + " roda")
		break

	var tint := Color("#6fbebf")
	Cars.set_paint(car, tint)
	_check(Cars.paint_tint(car) == tint, id + " preserva pintura")
	var tail: StandardMaterial3D = car.get_meta("tail")
	_check(tail != null, id + " oferece material de lanterna próprio")
	Cars.set_motion(car, 14.0, 0.4, true, 0.1)
	_check(tail.emission_energy_multiplier > 1.0, id + " acende a luz de freio")
	_check(absf(car.get_meta("front")[0].rotation.y) > 0.01, id + " esterça as rodas")

	var body: Mesh = car.get_meta("body").mesh
	var faces := body.get_faces()
	var profile: Dictionary = Cars.PROFILES[id]
	var width: float = profile.wheel.y
	var radius: float = profile.wheel.x
	for mount: Node3D in car.get_meta("front"):
		_wheel_clearance(faces, mount.position, width, radius, id, "dianteiro")
	var rear: Node3D = car.get_meta("rollers")[2].get_parent()
	_wheel_clearance(faces, rear.position, width, radius, id, "traseiro")
	car.free()


func _wheel_clearance(faces: PackedVector3Array, center: Vector3, width: float, radius: float,
		id: String, axle: String) -> void:
	for angle in [-0.93, -0.62, -0.32, 0.0, 0.32, 0.62, 0.93]:
		for lane in [-0.3, 0.0, 0.24]:
			var x: float = center.x + signf(center.x) * lane * width
			var origin := Vector3(x, 3.0, center.z + sin(angle) * radius)
			var tire_y: float = center.y + cos(angle) * radius
			var upper := -INF
			for j in range(0, faces.size(), 3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(origin, Vector3.DOWN,
					faces[j], faces[j + 1], faces[j + 2])
				if hit is Vector3:
					upper = maxf(upper, hit.y)
			if upper < tire_y + 0.005:
				_check(false, "%s cobre o pneu no eixo %s, x %.2f e z %.2f"
					% [id, axle, origin.x, origin.z])
				return


func _actor(i: int) -> void:
	var actor := Cast.new()
	root.add_child(actor)
	actor.build(i, i == Cast.CAST.size())
	var label := str(i)
	var geometry := actor._visual.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	_mesh(geometry.mesh, label + " vestuário")
	_check(geometry.skin.get_bind_count() == 12, label + " possui doze ossos")
	_check(actor._contacts[0].size() >= 10 and actor._contacts[1].size() >= 10,
		label + " importou os vértices da sola")
	for j in 48:
		actor.animate(1.0 / 60.0, 3.6 if j < 31 else 0.0)
		var lowest := INF
		for k in actor._feet.size():
			var pose := actor._rig.get_bone_global_pose(actor._feet[k])
			for point in actor._contacts[k]:
				lowest = minf(lowest, (pose * point).y + actor._visual.position.y)
		_check(is_equal_approx(lowest, 0.002), label + " mantém contato no piso")
	actor.free()


func _mesh(mesh: Mesh, label: String) -> void:
	_check(mesh is ArrayMesh and mesh.get_surface_count() > 0, label + " carrega malha indexada")
	for i in mesh.get_surface_count():
		var material := mesh.surface_get_material(i) as StandardMaterial3D
		_check(material != null and material.albedo_texture != null, label + " tem atlas no material")
		var arrays := mesh.surface_get_arrays(i)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		_check(uvs.size() == arrays[Mesh.ARRAY_VERTEX].size(), label + " mantém UV por vértice")
		for uv in uvs:
			if not uv.is_finite() or uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
				_check(false, label + " mantém UV no atlas")
				break


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
