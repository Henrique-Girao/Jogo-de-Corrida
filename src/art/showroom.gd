extends SubViewportContainer
## Prévia independente para a Oficina Ribeira e o Porto da Vigília.

const CarArt = preload("res://src/art/car_art.gd")
const ACID := Color("#cedc65")
const PAPER := Color("#b9b5a4")
const ASPHALT := Color("#303839")
const STEEL := Color("#39454b")
const DARK_STEEL := Color("#242e32")

static var _shadow_texture: ImageTexture
var _viewport: SubViewport
var _world: Node3D
var _stage: Node3D
var _vehicle: Node3D
var _camera: Camera3D
var _spec: Dictionary = {}
var _sector := "garage"
var _angle := -0.62
var _orbit_direction := 1.0
var _idle_time := 0.0
var _dragging := false
var _swipe := Vector2.ZERO
var _box_mesh := BoxMesh.new()
var _material_cache: Dictionary = {}


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(240, 180)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_camera = Camera3D.new()
	_camera.fov = 37.0
	_camera.near = 0.10
	_camera.far = 35.0
	_world.add_child(_camera)
	_camera.make_current()
	_rebuild_stage()
	_rebuild_vehicle()
	_update_camera()
	resized.connect(_update_camera)


func set_vehicle(spec: Dictionary) -> void:
	_spec = spec.duplicate()
	if is_node_ready():
		_rebuild_vehicle()


func set_sector(sector: String) -> void:
	if _sector == sector:
		return
	_sector = sector
	if is_node_ready():
		_rebuild_stage()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_idle_time += delta
	if _idle_time > 2.0 and not _dragging:
		if _angle >= -0.43:
			_orbit_direction = -1.0
		elif _angle <= -0.83:
			_orbit_direction = 1.0
		_angle += delta * 0.055 * _orbit_direction
		_update_camera()


func _gui_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_idle_time = 0.0
		accept_event()
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
		_idle_time = 0.0
		_swipe = Vector2.ZERO
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if _dragging:
			if event is InputEventScreenDrag:
				_swipe += event.relative
				if absf(_swipe.x) <= absf(_swipe.y):
					return
			_angle = clampf(_angle - event.relative.x * 0.009, -1.08, -0.19)
			_idle_time = -4.0
			_update_camera()
			accept_event()


func _update_camera() -> void:
	var aspect := size.x / maxf(size.y, 1.0)
	var distance := 6.15 + maxf(1.65 - aspect, 0.0) * 1.25
	var target := Vector3(0, 0.72, 0.0)
	_camera.position = target + Vector3(-sin(_angle) * distance, 1.39, -cos(_angle) * distance)
	_camera.look_at(target)


func _rebuild_vehicle() -> void:
	if is_instance_valid(_vehicle):
		_world.remove_child(_vehicle)
		_vehicle.queue_free()
	_vehicle = CarArt.create(_spec, 1)
	_world.add_child(_vehicle)


func _rebuild_stage() -> void:
	if is_instance_valid(_stage):
		_world.remove_child(_stage)
		_stage.queue_free()
	_stage = Node3D.new()
	_world.add_child(_stage)
	if _sector == "meet":
		_build_meet()
	else:
		_build_garage()
	_batch_geometry()


func _build_garage() -> void:
	_atmosphere(Color("#24333b"), Color("#c2d0d4"), 0.69)
	_light(Vector3(-3.3, 4.7, -2.4), Color("#fff0d5"), 2.15, true)
	_fill(Vector3(2.1, 2.0, -3.5), Color("#96b3c1"), 2.04, 8.0)
	_fill(Vector3(-2.0, 2.7, 2.4), Color("#ffe6b2"), 1.74, 8.0)
	_box(Vector3(0, -0.12, 0), Vector3(28, 0.24, 19), Color("#43494a"))
	_box(Vector3(0, 2.03, 4.2), Vector3(26, 4.1, 0.26), Color("#344148"))
	_box(Vector3(0, 0.65, 4.03), Vector3(26, 1.3, 0.084), Color("#252f34"))
	_box(Vector3(0, 1.33, 3.97), Vector3(26, 0.047, 0.03), ACID)
	_box(Vector3(-3.23, 1.56, 3.96), Vector3(2.76, 3.02, 0.095), Color("#0d151a"))
	_box(Vector3(-3.23, 1.49, 3.89), Vector3(2.54, 2.75, 0.064), Color("#414c52"))
	for step in range(12):
		_box(Vector3(-3.23, 0.17 + step * 0.235, 3.842), Vector3(2.47, 0.025, 0.025), Color("#262f35"))
	for panel in [-6.6, -1.6, 2.6, 6.8]:
		_box(Vector3(panel, 1.95, 3.92), Vector3(0.14, 3.9, 0.18), Color("#232e33"))
		_box(Vector3(panel, 0.24, 3.81), Vector3(0.21, 0.49, 0.10), Color("#59615d"))
	var placard := Vector3(0.25, 2.53, 3.82)
	_box(placard, Vector3(2.79, 0.60, 0.09), Color("#1b272b"))
	_box(placard - Vector3(1.324, 0, 0.056), Vector3(0.026, 0.51, 0.015), ACID)
	_sign("OFICINA RIBEIRA", placard - Vector3(-0.075, 0, 0.055), 46, 0.0056, PAPER)
	_box(Vector3(0.95, 0.54, 3.52), Vector3(1.98, 0.76, 0.64), Color("#38454b"))
	_box(Vector3(0.95, 0.94, 3.50), Vector3(2.09, 0.09, 0.76), Color("#171f23"))
	for drawer in range(3):
		_box(Vector3(0.95, 0.39 + drawer * 0.17, 3.188), Vector3(1.86, 0.03, 0.025), Color("#9ba6a0"))
	_box(Vector3(1.60, 1.01, 3.53), Vector3(0.48, 0.062, 0.28), Color("#4e777e"))
	_box(Vector3(5.1, 0.73, 3.55), Vector3(3.02, 1.46, 0.64), DARK_STEEL)
	for shelf in range(3):
		_box(Vector3(5.1, 0.09 + shelf * 0.58, 3.2), Vector3(2.84, 0.027, 0.07), Color("#5d6c70"))
	for x in [-5.0, 0.0, 5.0]:
		_box(Vector3(x, 3.71, 3.94), Vector3(3.25, 0.23, 0.24), DARK_STEEL)
		_emissive_strip(Vector3(x, 3.70, 3.80), Vector3(2.95, 0.061, 0.025), Color("#d2ddd7"))
	_detail_floor(Color("#9ba494"))
	_shadow(Vector3(0.15, 0.017, 0.06), Vector2(2.68, 5.12), 0.56)


func _build_meet() -> void:
	_atmosphere(Color("#1a3042"), Color("#a3c4e2"), 0.65)
	_light(Vector3(-3.0, 4.2, -1.5), Color("#f3d3a5"), 1.56, true)
	_fill(Vector3(2.8, 2.6, -3.2), Color("#98bbe7"), 2.55, 8.0)
	_fill(Vector3(-2.3, 2.5, 3.1), Color("#d58548"), 2.20, 8.0)
	_box(Vector3(0, -0.12, 0), Vector3(28, 0.24, 23), ASPHALT)
	_box(Vector3(0, 0.105, 5.36), Vector3(27, 0.21, 0.42), Color("#576264"))
	for i in range(-11, 12, 2):
		_box(Vector3(i, 0.211, 5.34), Vector3(0.91, 0.016, 0.38), Color("#bea968"))
	_container(Vector3(-4.6, 1.19, 7.0), Color("#865144"))
	_container(Vector3(2.9, 1.19, 7.4), Color("#354f61"))
	_container(Vector3(-5.30, 3.58, 7.19), Color("#534f49"))
	for x in [-6.5, 0.5, 6.5]:
		_box(Vector3(x, 2.19, 5.93), Vector3(0.09, 4.38, 0.093), Color("#252e39"))
		_box(Vector3(x, 4.30, 5.59), Vector3(0.13, 0.10, 0.74), Color("#171e28"))
		_emissive_strip(Vector3(x, 4.22, 5.25), Vector3(0.36, 0.031, 0.23), Color("#ffd28e"))
		_fill(Vector3(x, 4.03, 5.37), Color("#efb47d"), 1.42, 6.5)
	var placard := Vector3(0.28, 2.62, 6.11)
	_box(placard, Vector3(3.1, 0.64, 0.088), Color("#222c37"))
	_sign("PORTO DA VIGÍLIA", placard - Vector3(0, 0, 0.05), 42, 0.0057, PAPER)
	_detail_floor(Color("#7c795f"))
	_shadow(Vector3(0.15, 0.017, 0.06), Vector2(2.73, 5.15), 0.62)
	_parked({"model": "iris_22", "color": "#606ca8"}, Vector3(-3.3, 0, 3.12), 0.13)
	_parked({"model": "trovao_68", "color": "#9c6e3f"}, Vector3(3.6, 0, 3.02), -0.29)


func _detail_floor(mark: Color) -> void:
	for x in [-6.1, -1.77, 1.77, 6.1]:
		_box(Vector3(x, 0.008, 0), Vector3(0.035, 0.012, 12), Color("#313939"))
	for z in [-3.8, -0.56, 2.68, 5.34]:
		_box(Vector3(0, 0.009, z), Vector3(20, 0.011, 0.023), Color("#353d3d"))
	for side in [-1.0, 1.0]:
		for z in [-2.57, 2.52]:
			_box(Vector3(side * 1.48, 0.013, z), Vector3(0.53, 0.013, 0.058), mark)
			_box(Vector3(side * 1.71, 0.013, z * 0.929), Vector3(0.058, 0.013, 0.40), mark)
		for stripe in range(6):
			var tile := _box(Vector3(side * (2.60 + stripe * 0.19), 0.012, -2.0), Vector3(0.087, 0.014, 0.31), mark.darkened(0.24))
			tile.rotation.y = -0.64


func _container(at: Vector3, tint: Color) -> void:
	_box(at, Vector3(6.26, 2.39, 1.92), tint.darkened(0.16))
	for line in range(17):
		var pos := at + Vector3(-3.01 + line * 0.37, 0, -0.967)
		_box(pos, Vector3(0.102, 2.20, 0.07), tint)
	for h in [-1.12, 1.11]:
		_box(at + Vector3(0, h, -0.99), Vector3(6.28, 0.13, 0.07), tint.darkened(0.32))


func _parked(spec: Dictionary, at: Vector3, yaw: float) -> void:
	var car := CarArt.create(spec, 0)
	car.position = at
	car.rotation.y = yaw
	car.scale *= 0.91
	_stage.add_child(car)
	var ground := _shadow(at + Vector3(0, 0.02, 0), Vector2(2.54, 4.91), 0.65)
	ground.rotation.y = yaw


func _atmosphere(background: Color, ambient: Color, energy: float) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = energy
	var atmosphere := WorldEnvironment.new()
	atmosphere.environment = env
	_stage.add_child(atmosphere)


func _light(from: Vector3, tint: Color, energy: float, shadows: bool) -> void:
	var lamp := DirectionalLight3D.new()
	lamp.position = from
	lamp.light_color = tint
	lamp.light_energy = energy
	lamp.shadow_enabled = shadows
	lamp.directional_shadow_max_distance = 16.0
	lamp.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_stage.add_child(lamp)
	lamp.look_at(Vector3.ZERO)


func _fill(at: Vector3, tint: Color, energy: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = tint
	lamp.light_energy = energy
	lamp.omni_range = reach
	_stage.add_child(lamp)


func _sign(content: String, at: Vector3, font_size: int, pixel_size: float, tint: Color) -> void:
	var sign := Label3D.new()
	sign.position = at
	sign.rotation.y = PI
	sign.text = content
	sign.font_size = font_size
	sign.pixel_size = pixel_size
	sign.outline_size = 0
	sign.modulate = tint
	sign.shaded = true
	_stage.add_child(sign)


func _box(at: Vector3, size_box: Vector3, tint: Color) -> MeshInstance3D:
	var key := tint.to_html()
	if not _material_cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.roughness = 0.87
		_material_cache[key] = material
	var piece := MeshInstance3D.new()
	piece.mesh = _box_mesh
	piece.material_override = _material_cache[key]
	piece.position = at
	piece.scale = size_box
	_stage.add_child(piece)
	return piece


func _emissive_strip(at: Vector3, size_box: Vector3, tint: Color) -> void:
	var strip := _box(at, size_box, tint)
	var material: StandardMaterial3D = strip.material_override.duplicate()
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.65
	strip.material_override = material


func _batch_geometry() -> void:
	var geometry := SurfaceTool.new()
	geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arrays := _box_mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for child in _stage.get_children():
		var box := child as MeshInstance3D
		if box == null or box.mesh != _box_mesh:
			continue
		var material := box.material_override as StandardMaterial3D
		if material.emission_enabled:
			continue
		for index in indices:
			geometry.set_color(material.albedo_color)
			geometry.set_normal((box.transform.basis * normals[index]).normalized())
			geometry.add_vertex(box.transform * points[index])
		_stage.remove_child(box)
		box.queue_free()
	geometry.index()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.87
	geometry.set_material(material)
	var stage_mesh := MeshInstance3D.new()
	stage_mesh.name = "Cenário"
	stage_mesh.mesh = geometry.commit()
	_stage.add_child(stage_mesh)


func _shadow(at: Vector3, bounds: Vector2, strength: float) -> MeshInstance3D:
	if _shadow_texture == null:
		var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
		for x in 64:
			for y in 64:
				var uv := (Vector2(x, y) - Vector2(31.5, 31.5)) / 31.5
				var alpha := 1.0 - smoothstep(0.22, 1.0, uv.length())
				image.set_pixel(x, y, Color(0.018, 0.022, 0.025, alpha))
		_shadow_texture = ImageTexture.create_from_image(image)
	var plane := PlaneMesh.new()
	plane.size = bounds
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _shadow_texture
	material.albedo_color.a = strength
	var decal := MeshInstance3D.new()
	decal.position = at
	decal.mesh = plane
	decal.material_override = material
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stage.add_child(decal)
	return decal
