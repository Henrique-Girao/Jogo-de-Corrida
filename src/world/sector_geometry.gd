extends Node3D
## Meshes and collision volumes for the walkable districts.

const Style = preload("res://src/art/scene_style.gd")
const Models = preload("res://src/art/model_library.gd")
const Forms = preload("res://src/art/mesh_forms.gd")
const SOLID := 1
const STAGE := 2

var _boxes: Array[Transform3D] = []
var _paints: Array[Color] = []
var _beveled: Array[Transform3D] = []
var _bevel_colors: Array[Color] = []
var _luminous: Array[Transform3D] = []
var _light_colors: Array[Color] = []
var _blockers: StaticBody3D
var _models: Dictionary = {}


func box(at: Vector3, dimensions: Vector3, color: Color, solid := false, yaw := 0.0) -> void:
	_boxes.append(Transform3D(Basis(Vector3.UP, yaw).scaled_local(dimensions), at))
	_paints.append(color)
	if solid:
		block(at, dimensions, yaw)


func beveled(at: Vector3, dimensions: Vector3, color: Color, solid := false, yaw := 0.0) -> void:
	_beveled.append(Transform3D(Basis(Vector3.UP, yaw).scaled_local(dimensions), at))
	_bevel_colors.append(color)
	if solid:
		block(at, dimensions, yaw)


func beam(from: Vector3, to: Vector3, width: float, depth: float, color: Color) -> void:
	var span := to - from
	var up := Vector3.BACK if absf(span.normalized().y) > 0.98 else Vector3.UP
	var basis := Basis.looking_at(span, up).scaled_local(Vector3(width, depth, span.length()))
	_boxes.append(Transform3D(basis, (from + to) * 0.5))
	_paints.append(color)


func block(at: Vector3, dimensions: Vector3, yaw: float) -> void:
	if not is_instance_valid(_blockers):
		_blockers = StaticBody3D.new()
		_blockers.collision_layer = SOLID
		_blockers.collision_mask = 0
		add_child(_blockers)
	_shape(_blockers, at, dimensions, yaw)


func light_strip(at: Vector3, dimensions: Vector3, color: Color, yaw := 0.0) -> void:
	_luminous.append(Transform3D(Basis(Vector3.UP, yaw).scaled_local(dimensions), at))
	_light_colors.append(color)


func model(id: String, at: Vector3, dimensions := Vector3.ONE, yaw := 0.0, tint := Color.WHITE) -> void:
	if not _models.has(id):
		var poses: Array[Transform3D] = []
		var colors: Array[Color] = []
		_models[id] = [poses, colors]
	_models[id][0].append(Transform3D(Basis(Vector3.UP, yaw).scaled_local(dimensions), at))
	_models[id][1].append(tint)


func finish() -> void:
	_batch(_boxes, _paints, BoxMesh.new())
	_batch(_beveled, _bevel_colors, Forms.cabinet())
	_batch(_luminous, _light_colors, BoxMesh.new(), true)
	for id: String in _models:
		_batch(_models[id][0], _models[id][1], Models.prop(id), false, true)
	_models.clear()
	_boxes.clear()
	_paints.clear()
	_beveled.clear()
	_bevel_colors.clear()
	_luminous.clear()
	_light_colors.clear()


func surface(at: Vector3, dimensions: Vector3, color: Color, finish_name := "concrete", tile := 3.5, solid := true) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(dimensions.x, dimensions.z)
	var piece := MeshInstance3D.new()
	piece.mesh = plane
	piece.position = at
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.albedo_texture = Style.pavement(finish_name)
	paint.uv1_scale = Vector3(dimensions.x / tile, dimensions.z / tile, 1.0)
	paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	paint.roughness = 0.79 if finish_name == "slab" else 0.97
	piece.material_override = paint
	add_child(piece)
	if solid:
		block(at - Vector3(0, 0.18, 0), Vector3(dimensions.x, 0.34, dimensions.z), 0.0)


func glass(at: Vector3, dimensions: Vector3, color: Color, yaw: float) -> void:
	var material := _paint(color)
	material.roughness = 0.22
	material.metallic_specular = 0.66
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := QuadMesh.new()
	mesh.size = Vector2(dimensions.x, dimensions.y)
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.position = at
	piece.rotation.y = yaw
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)


func _batch(poses: Array[Transform3D], colors: Array[Color], mesh: Mesh, emissive := false, authored := false) -> void:
	if poses.is_empty():
		return
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = poses.size()
	for index in poses.size():
		batch.set_instance_transform(index, poses[index])
		batch.set_instance_color(index, colors[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	if not authored:
		var paint := _paint(Color.WHITE)
		paint.vertex_color_use_as_albedo = true
		if emissive:
			paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		instance.material_override = paint
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


static func collision_box(parent: Node3D, at: Vector3, dimensions: Vector3, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = SOLID
	body.collision_mask = 0
	parent.add_child(body)
	_shape(body, at, dimensions, yaw)
	return body


static func _shape(body: StaticBody3D, at: Vector3, dimensions: Vector3, yaw: float) -> void:
	var box_shape := BoxShape3D.new()
	box_shape.size = dimensions
	var shape := CollisionShape3D.new()
	shape.shape = box_shape
	shape.position = at
	shape.rotation.y = yaw
	body.add_child(shape)


static func _paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material
