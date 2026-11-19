extends CharacterBody3D
## Camera-relative ground movement with solid scenery and an obstruction-aware orbit.

const Person = preload("res://src/world/person_art.gd")
const Geometry = preload("res://src/world/sector_geometry.gd")
const WALK_SPEED := 4.6
const RUN_SPEED := 6.8
const LOOK_PER_PIXEL := 0.006
const CAMERA_DISTANCE := 4.95

var camera: Camera3D
var movement := Vector2.ZERO
var look_sensitivity := 1.0
var controls_enabled := true
var yaw := 0.0
var pitch := 0.29
var _visual: Person
var _camera_distance := CAMERA_DISTANCE
var _camera_side := 0.0
var _focused := false


func _ready() -> void:
	collision_layer = Geometry.STAGE
	collision_mask = Geometry.SOLID
	floor_snap_length = 0.26
	safe_margin = 0.035
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = 1.68
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.84
	add_child(shape)
	_visual = Person.new()
	add_child(_visual)
	_visual.build(12, true)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.10
	camera.far = 145.0
	add_child(camera)


func place(at: Vector3, heading: float, elevation: float) -> void:
	global_position = at
	yaw = heading
	pitch = elevation
	_camera_distance = CAMERA_DISTANCE
	_camera_side = 0.0
	_focused = false
	_visual.rotation.y = heading
	velocity = Vector3.ZERO
	update_camera(1.0)


func orbit(relative: Vector2) -> void:
	if not controls_enabled:
		return
	yaw = wrapf(yaw - relative.x * LOOK_PER_PIXEL * look_sensitivity, -PI, PI)
	pitch = clampf(pitch + relative.y * LOOK_PER_PIXEL * 0.75 * look_sensitivity, 0.10, 0.78)


func focus_on(point: Vector3) -> void:
	var toward := point - global_position
	if Vector2(toward.x, toward.z).length_squared() < 0.08:
		return
	_focused = true
	yaw = atan2(-toward.x, -toward.z)
	pitch = clampf(pitch, 0.24, 0.40)
	_visual.rotation.y = yaw


func release_focus() -> void:
	_focused = false


func reset_input() -> void:
	movement = Vector2.ZERO
	velocity.x = 0.0
	velocity.z = 0.0


func _physics_process(delta: float) -> void:
	if not controls_enabled:
		update_camera(delta)
		return
	var keys := Vector2(
		float(_pressed(KEY_D, KEY_RIGHT)) - float(_pressed(KEY_A, KEY_LEFT)),
		float(_pressed(KEY_S, KEY_DOWN)) - float(_pressed(KEY_W, KEY_UP))
	)
	var intent := (keys + movement).limit_length(1.0)
	var direction := Vector3(intent.x, 0.0, intent.y).rotated(Vector3.UP, yaw)
	var speed := RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, 24.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 24.0 * delta)
	velocity.y = -2.0 if is_on_floor() else maxf(-13.0, velocity.y - 16.0 * delta)
	move_and_slide()
	var actual := get_real_velocity()
	var horizontal_speed := Vector2(actual.x, actual.z).length()
	if direction.length_squared() > 0.04:
		var facing := atan2(-direction.x, -direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, facing, minf(delta * 15.0, 1.0))
	_visual.animate(delta, horizontal_speed)
	update_camera(delta)


func update_camera(delta: float) -> void:
	_camera_side = move_toward(_camera_side, 1.45 if _focused else 0.0, delta * 6.0)
	var side := Vector3.RIGHT.rotated(Vector3.UP, yaw) * _camera_side
	var anchor := global_position + Vector3.UP * 1.26 + side
	var backward := Vector3(0.0, sin(pitch), cos(pitch)).rotated(Vector3.UP, yaw)
	var distance := CAMERA_DISTANCE
	if get_world_3d():
		var ray := PhysicsRayQueryParameters3D.create(anchor, anchor + backward * (distance + 0.12), Geometry.SOLID)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			distance = maxf(0.33, anchor.distance_to(hit.position) - 0.22)
	_camera_distance = minf(distance, move_toward(_camera_distance, distance, delta * 9.0))
	camera.global_position = anchor + backward * _camera_distance
	camera.look_at(anchor, Vector3.UP)
	_visual.visible = _camera_distance > 0.78


func _pressed(first: Key, second: Key) -> bool:
	return Input.is_physical_key_pressed(first) or Input.is_physical_key_pressed(second)
