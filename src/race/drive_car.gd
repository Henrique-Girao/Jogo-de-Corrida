extends Node3D
## Planar simcade dynamics with a separate, road-aligned suspension visual.
## All speeds are in m/s, distances in metres and angles in radians.

const CarArt = preload("res://src/art/car_art.gd")
const Style = preload("res://src/art/scene_style.gd")
const GEAR_RATIOS: Array[float] = [0.24, 0.37, 0.51, 0.67, 0.84, 1.02]
const BODY_RADIUS := 1.05

var spec: Dictionary
var driver: Dictionary
var road_distance := 0.0
var progress_distance := 0.0
var finish_time := -1.0
var last_split_time := 0.0
var best_lap := -1.0
var splits := 0
var verified_distance := 0.0
var next_checkpoint := 0.0
var grounded_y := 0.0
var lane := 0.0
var initial_lane := 0.0
var velocity := Vector3.ZERO
var yaw := 0.0
var slip := 0.0
var throttle_input := 0.0
var brake_input := 0.0
var impact := 0.0
var off_track := false
var wrong_way := false
var rpm := 0.0
var gear := 1
var shift_hint := false
var shift_hold := 0.0
var shift_recovery := 0.0
var gear_quality := 1.0
var stopped_time := 0.0

var _model: Node3D
var _shadow: MeshInstance3D
var _visual_pitch := 0.0
var _visual_roll := 0.0
var _steer_angle := 0.0
var _suspension: float
var _previous_forward_speed := 0.0
var _speed_limit: float
var _launch_accel: float
var _grip: float
var _braking: float
var _handling: float
var _drive: String
var _mass: float
var _torque: float
var _power: float


func initialize(stats: Dictionary, profile: Dictionary, quality: int) -> void:
	spec = stats
	driver = profile
	_speed_limit = maxf(float(stats.get("top_speed", 172.0)) / 3.6, 24.0)
	_launch_accel = 30.0 / maxf(float(stats.get("acceleration", 10.5)), 2.5)
	_grip = clampf(float(stats.get("grip", 1.0)), 0.55, 1.85)
	_braking = clampf(float(stats.get("braking", 1.0)), 0.55, 1.9)
	_handling = clampf(float(stats.get("handling", 1.0)), 0.55, 1.8)
	_suspension = clampf(float(stats.get("lift", 1.0)), 0.55, 1.7)
	_drive = str(stats.get("drive", "FWD"))
	_mass = clampf(float(stats.get("weight", 1120.0)), 700.0, 2400.0)
	_torque = clampf(float(stats.get("torque", 150.0)), 90.0, 900.0)
	_power = clampf(float(stats.get("power", 108.0)), 70.0, 1000.0)
	_model = CarArt.create(stats, quality)
	add_child(_model)
	var dimensions := CarArt.dimensions(stats)
	_shadow = Style.shadow(dimensions.x * 1.55, dimensions.z * 1.25, 0.57, true)
	_shadow.position.y = -0.012
	add_child(_shadow)


func spawn_at(track, distance: float, lateral: float) -> void:
	var point: Dictionary = track.sample(distance)
	position = point.position + point.right * lateral
	grounded_y = position.y
	yaw = flat_yaw(point.forward)
	road_distance = distance
	lane = lateral
	velocity = Vector3.ZERO
	_steer_angle = 0.0
	_previous_forward_speed = 0.0
	_visual_pitch = 0.0
	_visual_roll = 0.0
	apply_pose(point, 1.0)


static func flat_yaw(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func speed() -> float:
	return velocity.length()


func displayed_gear() -> int:
	if velocity.dot(forward()) < -0.3:
		return -1
	return gear


func mass() -> float:
	return _mass


func car_grip() -> float:
	return _grip


func car_braking() -> float:
	return _braking


func max_speed() -> float:
	return _speed_limit


func shift_up() -> void:
	if shift_hold > 0.0 or gear >= GEAR_RATIOS.size():
		return
	var previous_rpm := rpm
	gear += 1
	var on_band := previous_rpm >= 0.76 and previous_rpm <= 0.97
	shift_hold = 0.11 if on_band else 0.23
	shift_recovery = 0.46
	gear_quality = 1.06 if on_band else lerpf(0.49, 0.78, previous_rpm)


func step(delta: float, steering: float, gas: float, brake: float, handbrake: bool, drag: bool, assist: bool, road: Dictionary) -> void:
	var heading := forward()
	var relative_speed := velocity.dot(heading)
	var total_speed := speed()
	var on_asphalt: bool = not off_track
	var speed_factor := clampf(total_speed / 32.0, 0.0, 1.0)
	var road_slope := float(road.grade) * heading.dot(road.forward)
	throttle_input = gas
	brake_input = brake
	impact = move_toward(impact, 0.0, delta * 1.8)

	# A high-speed wheel lock consumes grip even before the rear axle starts to slide.
	var load_transfer := clampf(brake * 0.33 - gas * 0.15 - road_slope * 0.2, -0.31, 0.42)
	var surface_grip := 1.0 if on_asphalt else 0.49
	var turn_capacity := _handling * lerpf(1.10, 0.77, speed_factor) * surface_grip
	var traction := _grip * surface_grip
	if _drive == "AWD":
		turn_capacity *= 0.96
	elif _drive == "RWD" and gas > 0.6:
		traction *= lerpf(0.77, 0.97, speed_factor)
	elif _drive == "FWD":
		turn_capacity *= 1.0 - gas * maxf(0.0, load_transfer + 0.17)
	if handbrake and not drag:
		traction *= 0.36
		turn_capacity *= 1.50

	var wheel_target := steering * turn_capacity
	_steer_angle = move_toward(_steer_angle, wheel_target, delta * (5.5 if assist else 7.5))
	var yaw_rate := _steer_angle * clampf(absf(relative_speed) / 7.0, 0.0, 1.0) * 1.67
	if absf(relative_speed) > 5.0 and assist:
		yaw_rate *= lerpf(1.0, 0.80, clampf(slip * 1.25, 0.0, 1.0))
	yaw = wrapf(yaw - yaw_rate * signf(relative_speed) * delta, -PI, PI)

	forward_drive(delta, relative_speed, gas, brake, drag, surface_grip, road_slope)
	var side := Vector3(cos(yaw), 0.0, -sin(yaw))
	var lateral_speed := velocity.dot(side)
	var correction := (5.8 + traction * 8.4) * (1.0 - maxf(load_transfer, 0.0) * 0.45 / _suspension)
	if assist:
		correction *= 1.16
	velocity -= side * signf(lateral_speed) * minf(absf(lateral_speed), correction * delta)
	if handbrake and not drag:
		velocity = velocity.move_toward(Vector3.ZERO, delta * 3.1)
	var handbrake_slip := 0.32 if handbrake and not drag and total_speed > 7.0 else 0.0
	slip = clampf(absf(lateral_speed) / 11.0 + handbrake_slip, 0.0, 1.0)
	position += velocity * delta

	var accel := (relative_speed - _previous_forward_speed) / maxf(delta, 0.001)
	_previous_forward_speed = relative_speed
	var pitch_target := clampf(accel * 0.0023 + load_transfer * -0.071, -0.052, 0.052)
	var roll_target := clampf(-_steer_angle * speed_factor * 0.10 / _suspension, -0.085, 0.085)
	_visual_pitch = lerpf(_visual_pitch, pitch_target, minf(delta * 9.0, 1.0))
	_visual_roll = lerpf(_visual_roll, roll_target, minf(delta * 10.0, 1.0))
	var braking_light := brake > 0.1 or (handbrake and not drag)
	CarArt.set_motion(_model, relative_speed, steering, braking_light, delta)


func forward_drive(delta: float, relative_speed: float, gas: float, brake: float, drag: bool, surface_grip: float, slope: float) -> void:
	var gear_limit := _speed_limit * GEAR_RATIOS[gear - 1]
	var drive_speed := absf(relative_speed)
	rpm = clampf(0.18 + drive_speed / gear_limit * 0.82, 0.18, 1.0)
	if drive_speed < 1.0:
		rpm = maxf(rpm, gas * 0.25)
	shift_hint = gear < GEAR_RATIOS.size() and rpm >= 0.80 and rpm <= 0.97
	if not drag:
		if rpm >= 0.94 and gear < GEAR_RATIOS.size():
			shift_up()
		elif gear > 1 and drive_speed < _speed_limit * GEAR_RATIOS[gear - 2] * 0.64:
			gear -= 1
	elif gear > 1 and drive_speed < _speed_limit * GEAR_RATIOS[gear - 2] * 0.43:
		gear -= 1
	shift_hold = maxf(shift_hold - delta, 0.0)
	shift_recovery = maxf(shift_recovery - delta, 0.0)

	var normalized_speed := clampf(drive_speed / _speed_limit, 0.0, 1.25)
	var sustained_accel := 1.55 + minf(_power / _mass * 12.0, 3.0)
	var engine_force := lerpf(_launch_accel * 1.48, sustained_accel, normalized_speed)
	engine_force *= clampf((_torque / _mass) * 2.8 + 0.70, 0.86, 1.44)
	engine_force *= 1.0 - pow(minf(normalized_speed, 1.0), 2.8) * 0.87
	if _drive == "AWD" and drive_speed < 16.0:
		engine_force *= lerpf(1.20, 1.0, drive_speed / 16.0)
	if shift_hold > 0.0:
		engine_force *= 0.16
	elif shift_recovery > 0.0:
		engine_force *= gear_quality
	if drag:
		engine_force *= clampf((1.055 - drive_speed / gear_limit) * 10.0, 0.0, 1.0)
		engine_force *= lerpf(0.67, 1.06, smoothstep(0.23, 0.70, rpm))

	var reverse := brake > 0.1 and gas < 0.1 and relative_speed <= 0.45 and not drag
	var drive := gas * maxf(engine_force, 0.0) * surface_grip
	if reverse:
		drive -= brake * 3.2 * clampf(1.0 + relative_speed / 8.0, 0.0, 1.0)
	else:
		var braking_force := brake * (8.9 * _braking)
		drive -= minf(braking_force, maxf(relative_speed, 0.0) / delta)
	velocity += forward() * (drive - slope * 7.2) * delta
	var rolling_resistance := 0.11 + normalized_speed * normalized_speed * 0.37
	if off_track:
		rolling_resistance += 1.5 + normalized_speed * 3.2
	velocity = velocity.move_toward(Vector3.ZERO, rolling_resistance * delta)
	if velocity.length_squared() > _speed_limit * _speed_limit:
		velocity = velocity.normalized() * _speed_limit


func apply_pose(road: Dictionary, delta: float) -> void:
	grounded_y = lerpf(grounded_y, float(road.position.y), minf(delta * 24.0, 1.0))
	position.y = grounded_y + 0.025
	var heading := forward()
	var gradient := float(road.grade) * heading.dot(Vector3(road.forward.x, 0.0, road.forward.z))
	heading.y = gradient
	heading = heading.normalized()
	var right := heading.cross(Vector3.UP).normalized()
	var up := right.cross(heading).normalized()
	basis = Basis(right, up, -heading)
	_shadow.visible = not off_track
	CarArt.set_body_lean(_model, _visual_pitch, _visual_roll, delta)
