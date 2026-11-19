extends Node3D
## Meshes and collision volumes for the walkable districts.

const Ui = preload("res://src/ui/ui_kit.gd")
const SOLID := 1
const STAGE := 2

static var _shadow_material: StandardMaterial3D
static var _ground_texture: ImageTexture

var _boxes: Array[Transform3D] = []
var _paints: Array[Color] = []
var _luminous: Array[Transform3D] = []
var _light_colors: Array[Color] = []
var _blockers: StaticBody3D


func box(at: Vector3, dimensions: Vector3, color: Color, solid := false, yaw := 0.0) -> void:
	var pose := Basis(Vector3.UP, yaw)
	_boxes.append(Transform3D(pose.scaled_local(dimensions), at))
	_paints.append(color)
	if solid:
		if not is_instance_valid(_blockers):
			_blockers = StaticBody3D.new()
			_blockers.collision_layer = SOLID
			_blockers.collision_mask = 0
			add_child(_blockers)
		_shape(_blockers, at, dimensions, yaw)


func light_strip(at: Vector3, dimensions: Vector3, color: Color, yaw := 0.0) -> void:
	_luminous.append(Transform3D(Basis(Vector3.UP, yaw).scaled_local(dimensions), at))
	_light_colors.append(color)


func finish() -> void:
	_batch(_boxes, _paints, false)
	_batch(_luminous, _light_colors, true)
	_boxes.clear()
	_paints.clear()
	_luminous.clear()
	_light_colors.clear()


func surface(at: Vector3, dimensions: Vector3, color: Color) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(dimensions.x, dimensions.z)
	var piece := MeshInstance3D.new()
	piece.mesh = plane
	piece.position = at
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.albedo_texture = _texture()
	paint.uv1_scale = Vector3(dimensions.x / 3.4, dimensions.z / 3.4, 1.0)
	paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	paint.roughness = 0.92
	piece.material_override = paint
	add_child(piece)
	box(at - Vector3(0, 0.18, 0), Vector3(dimensions.x, 0.34, dimensions.z), color, true)


func sign(words: String, at: Vector3, letter_scale: float, color: Color, yaw := 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.font = Ui.DISPLAY
	label.font_size = 58
	label.pixel_size = letter_scale
	label.outline_size = 0
	label.modulate = color
	label.rotation.y = yaw
	label.position = at
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(label)
	return label


func cylinder(at: Vector3, radius: float, height: float, color: Color, yaw := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = _paint(color)
	piece.position = at
	piece.rotation.y = yaw
	add_child(piece)
	return piece


func _batch(poses: Array[Transform3D], colors: Array[Color], emissive: bool) -> void:
	if poses.is_empty():
		return
	var paint := _paint(Color.WHITE)
	paint.vertex_color_use_as_albedo = true
	if emissive:
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = paint
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
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


static func collision_box(parent: Node3D, at: Vector3, dimensions: Vector3, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = SOLID
	body.collision_mask = 0
	parent.add_child(body)
	_shape(body, at, dimensions, yaw)
	return body


static func shadow(width: float, length: float) -> MeshInstance3D:
	if not is_instance_valid(_shadow_material):
		var image := Image.create_empty(40, 40, false, Image.FORMAT_RGBA8)
		for y in 40:
			for x in 40:
				var distance := Vector2(float(x) - 19.5, float(y) - 19.5).length() / 19.5
				image.set_pixel(x, y, Color(0.016, 0.025, 0.034, (1.0 - smoothstep(0.28, 1.0, distance)) * 0.65))
		_shadow_material = _paint(Color.WHITE)
		_shadow_material.albedo_texture = ImageTexture.create_from_image(image)
		_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_material.no_depth_test = false
		_shadow_material.texture_repeat = false
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, length)
	var instance := MeshInstance3D.new()
	instance.mesh = plane
	instance.material_override = _shadow_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


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


static func _texture() -> ImageTexture:
	if is_instance_valid(_ground_texture):
		return _ground_texture
	var image := Image.create_empty(96, 96, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 186
	noise.frequency = 0.09
	var random := RandomNumberGenerator.new()
	random.seed = 218
	for y in 96:
		for x in 96:
			var gray := 0.89 + noise.get_noise_2d(x, y) * 0.08 + random.randf_range(-0.055, 0.055)
			if mini(x, y) < 2:
				gray *= 0.79
			image.set_pixel(x, y, Color(gray, gray, gray))
	image.generate_mipmaps()
	_ground_texture = ImageTexture.create_from_image(image)
	return _ground_texture
