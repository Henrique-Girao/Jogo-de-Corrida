extends Node3D
## Owns an individual race. The caller pays entry or commits stakes before configuring it.

signal telemetry_changed(data: Dictionary)
signal race_finished(result: Dictionary)

const Track = preload("res://src/tracks/track.gd")
const DriveCar = preload("res://src/race/drive_car.gd")

const COUNTDOWN_TIME := 3.4
const CHECKPOINT_GAP := 42.0
const DRIVER_NAMES := ["Nina", "Téo", "Beto", "Lia", "Duda"]

var _event: Dictionary
var _player_spec: Dictionary
var _opponents: Array
var _options: Dictionary
var _track
var _cars: Array[DriveCar] = []
var _standings: Array[DriveCar] = []
var _player: DriveCar
var _camera: Camera3D
var _camera_aim := Vector3.ZERO
var _camera_mode := 0
var _mode := "circuit"
var _laps := 1
var _race_distance := 0.0
var _start_distance := 0.0
var _countdown := COUNTDOWN_TIME
var _elapsed := 0.0
var _telemetry_clock := 0.0
var _time_limit := 180.0
var _sensitivity := 1.0
var _traction_control := true
var _paused := false
var _finished := false
var _touch_steer := 0.0
var _touch_throttle := 0.0
var _touch_brake := 0.0
var _touch_handbrake := false
var _was_handbrake := false
var _was_reset := false
var _was_camera := false
var _time_penalty := 0.0
var _final_result: Dictionary = {}


func configure(event: Dictionary, player_spec: Dictionary, opponents: Array, options: Dictionary = {}) -> void:
	_event = event.duplicate(true)
	_player_spec = player_spec.duplicate(true)
	_opponents = opponents.duplicate(true)
	_options = options.duplicate(true)


func _ready() -> void:
	if _event == null or _event.is_empty():
		push_error("Uma corrida precisa de um evento antes de entrar na árvore.")
		set_physics_process(false)
		return
	_mode = str(_event.get("mode", "circuit"))
	_traction_control = bool(_options.get("assists", true))
	_sensitivity = clampf(float(_options.get("sensitivity", 1.0)), 0.35, 2.0)
	_camera_mode = int(_options.get("camera", 0))
	var quality := 1
	match str(_options.get("quality", "auto")):
		"low", "0":
			quality = 0
		"high", "2":
			quality = 2
	_track = Track.new()
	add_child(_track)
	var course_mode := str(_event.get("course_mode", _mode))
	_track.build(str(_event.get("track", "autodromo")), course_mode, quality)
	_laps = maxi(int(_event.get("laps", 1)), 1) if _track.closed else 1
	_race_distance = float(_track.length) * _laps
	_time_limit = maxf(100.0, _race_distance / 6.0 + 25.0)

	var opponents := _opponents
	if opponents.is_empty():
		opponents = fallback_opponents()
	spawn_field(opponents, quality)
	update_standings()
	build_camera()
	send_telemetry()


func spawn_field(opponents: Array, quality: int) -> void:
	var rival_count := mini(opponents.size(), 5)
	if _mode == "drag":
		rival_count = mini(rival_count, 1)
	var car_count := rival_count + 1
	for index in range(car_count):
		var is_player := index == car_count - 1
		var profile: Dictionary = {"id": "player", "name": "Você"} if is_player else opponents[index]
		var stats: Dictionary = _player_spec
		if not is_player:
			var rival_spec: Variant = profile.get("spec", profile.get("car", {}))
			if rival_spec is Dictionary and not rival_spec.is_empty():
				stats = rival_spec
		var car := DriveCar.new()
		add_child(car)
		car.initialize(stats, profile, quality if is_player else maxi(0, quality - 1))
		var distance := maxf(4.0, 16.0 - floorf(index * 0.5) * 6.0)
		var lateral := -1.7 if index % 2 == 0 else 1.7
		if car_count == 1:
			lateral = 0.0
		elif car_count == 2:
			distance = 16.0
		if _mode == "drag":
			distance = 3.0
			lateral = -2.2 if index == 0 else 2.2
		car.initial_lane = lateral
		car.spawn_at(_track, distance, lateral)
		car.progress_distance = distance
		car.verified_distance = distance
		car.next_checkpoint = distance + CHECKPOINT_GAP
		_cars.append(car)
		if is_player:
			_player = car
			_start_distance = distance


func fallback_opponents() -> Array:
	var rivals := []
	var colors := ["#45A391", "#DF6349", "#DFB551", "#5A77B0", "#ADB8A7"]
	for index in range(clampi(int(_event.get("opponents", 0)), 0, 5)):
		var spec := _player_spec.duplicate()
		spec["color"] = colors[index]
		rivals.append({
			"id": "local_%d" % index,
			"name": DRIVER_NAMES[index],
			"spec": spec,
			"skill": 0.48 + index * 0.065,
			"aggression": 0.37 + index * 0.12
		})
	return rivals


func build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "ChaseCamera"
	_camera.near = 0.18
	_camera.far = 700.0
	_camera.fov = 68.0
	add_child(_camera)
	_camera.make_current()
	update_camera(1.0)


func set_controls(steer: float, throttle: float, brake: float, handbrake: bool = false) -> void:
	_touch_steer = clampf(steer, -1.0, 1.0)
	_touch_throttle = clampf(throttle, 0.0, 1.0)
	_touch_brake = clampf(brake, 0.0, 1.0)
	_touch_handbrake = handbrake


func clear_controls() -> void:
	set_controls(0.0, 0.0, 0.0, false)


func set_paused(value: bool) -> void:
	_paused = value
	clear_controls()
	_was_handbrake = false
	if is_instance_valid(_player):
		send_telemetry()


func cycle_camera() -> int:
	_camera_mode = (_camera_mode + 1) % 2
	return _camera_mode


func course_outline() -> PackedVector2Array:
	if is_instance_valid(_track):
		return _track.course_outline()
	return PackedVector2Array()


func shift_up() -> void:
	if _mode == "drag" and _countdown <= 0.0 and not _paused and not _finished:
		_player.shift_up()


func reset_player() -> void:
	if _countdown > 0.0 or _finished or not is_instance_valid(_player):
		return
	reset_car(_player)
	if _mode == "time_trial":
		_time_penalty += 3.0


func abort() -> void:
	if not _finished and is_instance_valid(_player):
		finish_race(false)


func _physics_process(delta: float) -> void:
	if _paused or _finished:
		return
	var controls := read_controls()
	if _countdown > 0.0:
		_countdown = maxf(_countdown - delta, 0.0)
		_player.throttle_input = controls.y
		_player.rpm = move_toward(_player.rpm, 0.17 + controls.y * 0.50, delta * 2.8)
	else:
		_elapsed += delta
		if _mode == "drag" and controls.w > 0.0 and not _was_handbrake:
			shift_up()
		step_grid(delta, controls)
		update_standings()
		if _player.finish_time >= 0.0:
			finish_race(true)
		elif _elapsed >= _time_limit:
			finish_race(false)
	_was_handbrake = controls.w > 0.0
	update_camera(delta)
	_telemetry_clock += delta
	if _telemetry_clock >= 0.048:
		_telemetry_clock = 0.0
		send_telemetry()


func read_controls() -> Vector4:
	var keyboard_steer := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
	keyboard_steer -= float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var gas := float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var brake := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	var handbrake := _touch_handbrake or Input.is_physical_key_pressed(KEY_SPACE)
	var wants_reset := Input.is_physical_key_pressed(KEY_R)
	if wants_reset and not _was_reset:
		reset_player()
	_was_reset = wants_reset
	var wants_camera := Input.is_physical_key_pressed(KEY_C)
	if wants_camera and not _was_camera:
		cycle_camera()
	_was_camera = wants_camera

	var steering := clampf(keyboard_steer + _touch_steer, -1.0, 1.0)
	var controller_ids := Input.get_connected_joypads()
	if not controller_ids.is_empty():
		var controller := controller_ids[0]
		var stick := Input.get_joy_axis(controller, JOY_AXIS_LEFT_X)
		if absf(stick) > 0.17:
			steering = stick
		gas = maxf(gas, Input.get_joy_axis(controller, JOY_AXIS_TRIGGER_RIGHT))
		brake = maxf(brake, Input.get_joy_axis(controller, JOY_AXIS_TRIGGER_LEFT))
		handbrake = handbrake or Input.is_joy_button_pressed(controller, JOY_BUTTON_A)
	steering = clampf(steering * _sensitivity, -1.0, 1.0)
	return Vector4(steering, maxf(gas, _touch_throttle), maxf(brake, _touch_brake), float(handbrake))


func step_grid(delta: float, player_controls: Vector4) -> void:
	for car in _cars:
		if car.finish_time >= 0.0:
			continue
		var road: Dictionary = _track.sample(car.road_distance)
		var controls := player_controls if car == _player else choose_ai_controls(car)
		car.step(delta, controls.x, controls.y, controls.z, controls.w > 0.0, _mode == "drag",
			_traction_control if car == _player else true, road)
	if _mode != "drag":
		collide_cars()
	for car in _cars:
		if car.finish_time < 0.0:
			update_car_road(car, delta)


func choose_ai_controls(car: DriveCar) -> Vector4:
	var speed := car.speed()
	var skill := clampf(float(car.driver.get("skill", 0.60)), 0.22, 1.0)
	var aggression := clampf(float(car.driver.get("aggression", 0.50)), 0.0, 1.0)
	var look_ahead := 9.0 + speed * lerpf(0.32, 0.51, skill)
	var lane_target := car.initial_lane
	if _mode != "drag":
		var corner: Dictionary = _track.sample(car.road_distance + maxf(9.0, speed * 0.9))
		var racing_line := clampf(float(corner.curvature) * 62.0, -1.3, 1.3)
		lane_target = lerpf(car.initial_lane * 0.12, racing_line, 0.72)
		lane_target += overtake_offset(car, aggression)
		lane_target = clampf(lane_target, -float(_track.half_width) + 1.5, float(_track.half_width) - 1.5)
		lane_target = lerpf(car.initial_lane, lane_target, smoothstep(0.10, 2.5, _elapsed))

	var target: Dictionary = _track.sample(car.road_distance + look_ahead)
	var aim: Vector3 = target.position + target.right * lane_target - car.position
	if aim.length_squared() < 4.0:
		aim = target.forward
	var yaw_error := wrapf(car.yaw - DriveCar.flat_yaw(aim), -PI, PI)
	# Divide by estimated yaw authority for a speed-independent response.
	var desired_steer := clampf(yaw_error * (2.45 + skill * 0.7), -1.0, 1.0)

	if _mode == "drag":
		var shift_point := lerpf(0.99, 0.87, skill)
		if car.rpm >= shift_point:
			car.shift_up()
		var start_delay := lerpf(0.42, 0.12, skill)
		var drive := lerpf(0.94, 1.0, skill) if _elapsed > start_delay else 0.0
		return Vector4(desired_steer * 0.5, drive, 0.0, 0.0)

	var max_speed := car.max_speed() * lerpf(0.69, 0.96, skill)
	var desired_speed := max_speed
	var look_step := maxf(9.0, speed * 0.39)
	for index in range(1, 6):
		var distance := look_step * index
		var corner: Dictionary = _track.sample(car.road_distance + distance)
		var curvature := maxf(absf(float(corner.curvature)), 0.0006)
		var corner_speed := sqrt(car.car_grip() * lerpf(5.0, 9.1, skill) / curvature)
		var approaching_speed := sqrt(corner_speed * corner_speed + 2.0 * car.car_braking() * lerpf(2.9, 5.9, skill) * maxf(0.0, distance - 5.0))
		desired_speed = minf(desired_speed, approaching_speed)
	if absf(yaw_error) > 0.37:
		desired_speed *= clampf(1.0 - absf(yaw_error) * 0.35, 0.32, 1.0)

	var speed_difference := desired_speed - speed
	var gas := clampf((speed_difference + 1.4) * 0.27, 0.0, lerpf(0.81, 1.0, skill))
	var brake := clampf((-speed_difference - 0.9) * 0.15, 0.0, 1.0)
	if car.off_track and absf(yaw_error) < 0.4:
		gas = maxf(0.45, gas)
	return Vector4(desired_steer, gas, brake, 0.0)


func overtake_offset(car: DriveCar, aggression: float) -> float:
	var offset := 0.0
	for other in _cars:
		var ahead := other.progress_distance - car.progress_distance
		if other == car or other.finish_time >= 0.0 or ahead < -1.0 or ahead > (12.0 + aggression * 10.0):
			continue
		if absf(other.lane - car.lane) < 2.9:
			var side := signf(car.lane - other.lane)
			if side == 0.0:
				side = signf(car.initial_lane)
			offset += side * lerpf(1.8, 3.7, aggression)
	return clampf(offset, -4.4, 4.4)


func collide_cars() -> void:
	for first_index in range(_cars.size()):
		var first := _cars[first_index]
		if first.finish_time >= 0.0:
			continue
		for second_index in range(first_index + 1, _cars.size()):
			var second := _cars[second_index]
			if second.finish_time >= 0.0 or absf(first.position.y - second.position.y) > 1.3:
				continue
			# Two discs per body approximate vehicle length without physics-engine joints.
			for first_offset: float in [-1.02, 1.02]:
				for second_offset: float in [-1.02, 1.02]:
					var separation := first.position + first.forward() * first_offset
					separation -= second.position + second.forward() * second_offset
					separation.y = 0.0
					var distance := separation.length()
					if distance >= DriveCar.BODY_RADIUS * 2.0 or distance < 0.001:
						continue
					var normal := separation / distance
					var first_weight := second.mass() / (first.mass() + second.mass())
					var penetration := DriveCar.BODY_RADIUS * 2.0 - distance
					first.position += normal * penetration * first_weight
					second.position -= normal * penetration * (1.0 - first_weight)
					var closing := (first.velocity - second.velocity).dot(normal)
					if closing >= 0.0:
						continue
					first.velocity -= normal * closing * first_weight * 1.18
					second.velocity += normal * closing * (1.0 - first_weight) * 1.18
					var hit := clampf(-closing / 16.0, 0.0, 1.0)
					first.impact = maxf(first.impact, hit)
					second.impact = maxf(second.impact, hit)


func update_car_road(car: DriveCar, delta: float) -> void:
	var road: Dictionary = _track.project(car.position, car.road_distance)
	var distance := float(road.distance)
	var advance := distance - car.road_distance
	var length_m := float(_track.length)
	if _track.closed:
		advance = wrapf(advance, -length_m * 0.5, length_m * 0.5)
	if absf(advance) > 15.0 + car.speed() * delta:
		if car == _player:
			reset_player()
		else:
			reset_car(car)
		return
	car.progress_distance += advance
	car.road_distance = distance
	car.lane = float(road.lateral)
	car.off_track = absf(car.lane) > float(_track.half_width) - 0.35
	car.wrong_way = car.forward().dot(road.forward) < -0.31 and car.speed() > 2.0

	var barrier := float(_track.half_width) + 2.0
	if absf(car.lane) > barrier:
		var normal: Vector3 = road.right * signf(car.lane)
		normal.y = 0.0
		normal = normal.normalized()
		car.position -= normal * (absf(car.lane) - barrier + 0.08)
		var impact_speed := car.velocity.dot(normal)
		if impact_speed > 0.5:
			car.velocity = (car.velocity - normal * impact_speed * 1.32) * 0.60
			car.impact = maxf(car.impact, clampf(impact_speed / 16.0, 0.0, 1.0))
		car.lane = barrier * signf(car.lane)
	if not _track.closed:
		var travel: Vector3 = car.position - road.position
		if distance <= 0.01 and travel.dot(road.forward) < -12.0:
			reset_car(car)
			return
		if distance >= length_m - 0.01 and travel.dot(road.forward) > 22.0:
			if car == _player:
				reset_player()
			else:
				reset_car(car)
			return

	var legally_on_course := not car.off_track and not car.wrong_way
	if legally_on_course and car.progress_distance >= car.next_checkpoint:
		car.verified_distance = car.progress_distance
		car.next_checkpoint = car.verified_distance + CHECKPOINT_GAP
	if absf(car.lane) < float(_track.half_width) + 1.0 and not car.wrong_way:
		register_laps(car, length_m)
	if car.wrong_way or (car.off_track and car.speed() < 2.0):
		car.stopped_time += delta
	else:
		car.stopped_time = 0.0
	if car.stopped_time > (5.5 if car == _player else 3.6):
		if car == _player:
			reset_player()
		else:
			reset_car(car)
		return
	car.apply_pose(road, delta)


func register_laps(car: DriveCar, length_m: float) -> void:
	var chrono := _elapsed + (_time_penalty if car == _player else 0.0)
	if car.progress_distance >= _race_distance - 0.015:
		car.finish_time = chrono
		var final_split := chrono - car.last_split_time
		car.best_lap = final_split if car.best_lap < 0.0 else minf(car.best_lap, final_split)
		return
	if not _track.closed:
		return
	var crossed := int(floorf(car.progress_distance / length_m))
	# Record a split once per completed lap, including after a recovery near the stripe.
	if crossed > car.splits:
		var lap := chrono - car.last_split_time
		car.best_lap = lap if car.best_lap < 0.0 else minf(lap, car.best_lap)
		car.last_split_time = chrono
		car.splits = crossed


func reset_car(car: DriveCar) -> void:
	var recovery_distance := minf(car.verified_distance, _race_distance - 12.0)
	var local_distance := recovery_distance
	if _track.closed:
		local_distance = fposmod(recovery_distance, float(_track.length))
	var recovery_lane := car.initial_lane if _mode == "drag" else 0.0
	car.spawn_at(_track, local_distance, recovery_lane)
	car.progress_distance = recovery_distance
	car.stopped_time = 0.0
	car.off_track = false
	car.wrong_way = false


func update_standings() -> void:
	_standings.assign(_cars)
	_standings.sort_custom(func(first: DriveCar, second: DriveCar) -> bool:
		if first.finish_time >= 0.0 and second.finish_time >= 0.0:
			return first.finish_time < second.finish_time
		if first.finish_time >= 0.0 or second.finish_time >= 0.0:
			return first.finish_time >= 0.0
		return first.progress_distance > second.progress_distance
	)


func update_camera(delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	var heading := _player.forward()
	var road: Dictionary = _track.sample(_player.road_distance)
	var road_heading := Vector3(road.forward.x, 0.0, road.forward.z).normalized()
	if heading.dot(road_heading) > 0.28:
		heading = heading.lerp(road_heading, 0.24).normalized()
	var speed_fraction := clampf(_player.speed() / 55.0, 0.0, 1.0)
	var height := 3.25 if _camera_mode == 0 else 5.0
	var distance := (7.9 if _camera_mode == 0 else 10.7) + speed_fraction * 1.8
	var camera_position := _player.position - heading * distance + Vector3.UP * height
	var camera_road: Dictionary = _track.project(camera_position, _player.road_distance)
	camera_position.y = maxf(camera_position.y, float(camera_road.position.y) + 1.7)
	var aim := _player.position + heading * (6.8 + speed_fraction * 5.4) + Vector3.UP * 0.95
	var blend := minf(delta * 6.8, 1.0)
	_camera.position = _camera.position.lerp(camera_position, blend)
	_camera_aim = _camera_aim.lerp(aim, blend)
	_camera.look_at(_camera_aim, Vector3.UP)
	_camera.fov = lerpf(_camera.fov, 63.0 + speed_fraction * 12.0, minf(delta * 2.7, 1.0))


func send_telemetry() -> void:
	var countdown := int(ceil(_countdown - 0.4)) if _countdown > 0.4 else 1
	if _countdown <= 0.0:
		countdown = 0 if _elapsed < 0.65 and not _finished else -1
	var chrono := _elapsed + _time_penalty
	var rival_points := PackedVector2Array()
	for car in _cars:
		if car != _player:
			rival_points.append(_track.progress_point(car.road_distance))
	var phase := "countdown" if _countdown > 0.0 else "racing"
	if _finished:
		phase = "finished"
	var telemetry := {
		"speed_kmh": _player.speed() * 3.6, "rpm": _player.rpm, "gear": _player.displayed_gear(),
		"time": chrono, "time_ms": roundi(chrono * 1000.0),
		"position": maxi(_standings.find(_player) + 1, 1),
		"field_size": _cars.size(),
		"lap": clampi(int(floorf(_player.progress_distance / float(_track.length))) + 1, 1, _laps),
		"laps": _laps, "countdown": countdown,
		"heat": int(_event.get("round", 1)), "heat_total": int(_event.get("rounds", 1)),
		"progress": clampf((_player.progress_distance - _start_distance) / maxf(_race_distance - _start_distance, 1.0), 0.0, 1.0),
		"wrong_way": _player.wrong_way, "off_track": _player.off_track, "phase": phase,
		"mode": _mode, "paused": _paused,
		"target_ms": int(_event.get("target_ms", 0)),
		"best_lap_ms": roundi(_player.best_lap * 1000.0) if _player.best_lap > 0.0 else 0,
		"shift_hint": _player.shift_hint,
		"slip": _player.slip, "throttle": _player.throttle_input, "brake": _player.brake_input,
		"impact": _player.impact,
		"map_position": _track.progress_point(_player.road_distance),
		"map_rivals": rival_points
	}
	telemetry_changed.emit(telemetry)


func finish_race(completed: bool) -> void:
	_finished = true
	clear_controls()
	update_standings()
	var position := _standings.find(_player) + 1 if completed else _cars.size()
	var finish_time := _player.finish_time if completed else _elapsed + _time_penalty
	var time_ms := roundi(finish_time * 1000.0)
	var target_ms := int(_event.get("target_ms", 0))
	var won := completed and position == 1
	if target_ms > 0 and (_mode == "time_trial" or _cars.size() == 1):
		won = completed and time_ms <= target_ms
		position = 1 if won else 2
	var results := []
	if not completed:
		_standings.erase(_player)
		_standings.append(_player)
	for index in range(_standings.size()):
		var car := _standings[index]
		results.append({
			"position": position if car == _player else index + 1,
			"id": str(car.driver.get("id", "")),
			"name": str(car.driver.get("name", "Piloto")),
			"car": str(car.spec.get("name", "")),
			"time_ms": roundi(car.finish_time * 1000.0) if car.finish_time >= 0.0 else 0,
			"completed": car.finish_time >= 0.0
		})
	_final_result = {
		"position": position, "time": finish_time, "time_ms": time_ms,
		"completed": completed, "won": won, "field_size": _cars.size(), "mode": _mode,
		"event_id": str(_event.get("id", "")),
		"best_lap_ms": roundi(_player.best_lap * 1000.0) if _player.best_lap > 0.0 else 0,
		"speed_kmh": _player.speed() * 3.6, "results": results
	}
	send_telemetry()
	race_finished.emit(_final_result.duplicate(true))
