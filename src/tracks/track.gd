extends Node3D
## A sampled road centerline shared by rendering, cars, AI and the course map.

const RouteData = preload("res://src/tracks/route_data.gd")
const Dressing = preload("res://src/tracks/track_dressing.gd")
const SPACING := 4.0

var length := 0.0
var half_width := 7.0
var closed := false
var route_name := ""
var track_id := ""
var mode := ""
var start_line := 22.0
var quality := 1

var _points := PackedVector3Array()
var _directions := PackedVector3Array()
var _curves := PackedFloat32Array()
var _interval := SPACING
var _minimum := Vector2.ZERO
var _maximum := Vector2.ZERO
var _visuals: Node3D


func build(requested_track: String, requested_mode: String = "circuit", requested_quality: int = 1) -> void:
	var config := _prepare(requested_track, requested_mode)
	quality = clampi(requested_quality, 0, 2)
	if is_instance_valid(_visuals):
		remove_child(_visuals)
		_visuals.queue_free()
	_visuals = Dressing.new()
	add_child(_visuals)
	_visuals.build(self, config)


static func map_preview(requested_track: String, requested_mode: String = "circuit") -> PackedVector2Array:
	var track := new()
	track._prepare(requested_track, requested_mode)
	var points := track.course_outline()
	track.free()
	return points


func _prepare(requested_track: String, requested_mode: String) -> Dictionary:
	track_id = requested_track if requested_track in ["autodromo", "docas", "serra"] else "autodromo"
	mode = requested_mode
	var config := RouteData.get_route(track_id)
	route_name = config.name
	half_width = config.half_width
	closed = mode == "circuit"
	start_line = 3.0 if mode == "drag" else 22.0
	var anchors := PackedVector3Array(config.points)
	if mode == "drag":
		anchors = PackedVector3Array([Vector3(0, 0.65, 0), Vector3(0, 0.65, 135.112), Vector3(0, 0.65, 270.224), Vector3(0, 0.65, 405.336)])
		half_width = 6.8
	elif closed and config.has("circuit_return"):
		anchors.append_array(PackedVector3Array(config.circuit_return))
	_create_centerline(anchors)
	return config


func sample(distance: float) -> Dictionary:
	var d := fposmod(distance, length) if closed else clampf(distance, 0.0, length)
	var raw_index := d / _interval
	var i := mini(floori(raw_index), _points.size() - 2)
	var alpha := raw_index - i
	var forward := _directions[i].lerp(_directions[i + 1], alpha).normalized()
	var p := _points[i].lerp(_points[i + 1], alpha)
	return {
		"position": p,
		"forward": forward,
		"right": forward.cross(Vector3.UP).normalized(),
		"curvature": lerpf(_curves[i], _curves[i + 1], alpha),
		"grade": forward.y,
	}


func project(world_position: Vector3, near_distance: float = NAN) -> Dictionary:
	var segment_count := _points.size() - 1
	var first_index := 0
	var last_index := segment_count - 1
	var limited := is_finite(near_distance)
	if limited:
		var near := fposmod(near_distance, length) if closed else clampf(near_distance, 0.0, length)
		var index := floori(near / _interval)
		first_index = index - 17 if closed else maxi(0, index - 17)
		last_index = index + 17 if closed else mini(segment_count - 1, index + 17)
	var nearest := INF
	var best_distance := 0.0
	for segment in range(first_index, last_index + 1):
		var i := posmod(segment, segment_count) if closed else segment
		var start := _points[i]
		var heading := _points[i + 1] - start
		var fraction := clampf((world_position - start).dot(heading) / heading.length_squared(), 0.0, 1.0)
		var squared := world_position.distance_squared_to(start + heading * fraction)
		if squared < nearest:
			nearest = squared
			best_distance = (i + fraction) * _interval
	if limited and nearest > 2500.0:
		return project(world_position)
	if closed:
		best_distance = fposmod(best_distance, length)
	var result := sample(best_distance)
	var offset: Vector3 = world_position - result.position
	result.distance = best_distance
	result.lateral = offset.dot(result.right)
	return result


func course_outline() -> PackedVector2Array:
	var outline := PackedVector2Array()
	for i in range(0, _points.size() - 1, 4):
		outline.append(_minimap(_points[i]))
	outline.append(_minimap(_points[_points.size() - 1]))
	return outline


func progress_point(distance: float) -> Vector2:
	return _minimap(sample(distance).position)


func bounds() -> Rect2:
	return Rect2(_minimum, _maximum - _minimum)


func _minimap(point: Vector3) -> Vector2:
	var span := _maximum - _minimum
	var center := (_maximum + _minimum) * 0.5
	var scale := maxf(span.x, span.y)
	return (Vector2(point.x, -point.z) - center) / scale + Vector2(0.5, 0.5)


func _create_centerline(anchors: PackedVector3Array) -> void:
	var raw := PackedVector3Array([anchors[0]])
	var offsets := PackedFloat32Array([0.0])
	var segments := anchors.size() if closed else anchors.size() - 1
	var raw_length := 0.0
	for i in segments:
		var p0 := _anchor(anchors, i - 1)
		var p1 := anchors[i]
		var p2 := _anchor(anchors, i + 1)
		var p3 := _anchor(anchors, i + 2)
		for j in range(1, 23):
			var t := j / 22.0
			var t2 := t * t
			var t3 := t2 * t
			var p := (2.0 * p1 + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3) * 0.5
			raw_length += p.distance_to(raw[-1])
			raw.append(p)
			offsets.append(raw_length)
	length = raw_length
	var step_count := maxi(2, ceili(length / SPACING))
	_interval = length / step_count
	_points.resize(step_count + 1)
	_directions.resize(step_count + 1)
	_curves.resize(step_count + 1)
	var next := 1
	_minimum = Vector2(INF, INF)
	_maximum = Vector2(-INF, -INF)
	for i in range(step_count + 1):
		var target := minf(i * _interval, offsets[-1])
		while next < raw.size() - 1 and offsets[next] < target:
			next += 1
		var blend := inverse_lerp(offsets[next - 1], offsets[next], target)
		var point := raw[next - 1].lerp(raw[next], blend)
		_points[i] = point
		var map_point := Vector2(point.x, -point.z)
		_minimum = _minimum.min(map_point)
		_maximum = _maximum.max(map_point)
	for i in range(step_count + 1):
		var before := posmod(i - 1, step_count) if closed else maxi(i - 1, 0)
		var after := posmod(i + 1, step_count) if closed else mini(i + 1, step_count)
		_directions[i] = (_points[after] - _points[before]).normalized()
	for i in range(step_count + 1):
		var before := posmod(i - 2, step_count) if closed else maxi(i - 2, 0)
		var after := posmod(i + 2, step_count) if closed else mini(i + 2, step_count)
		var a := _directions[before]
		var b := _directions[after]
		_curves[i] = a.signed_angle_to(b, Vector3.UP) / (4.0 * _interval)


func _anchor(anchors: PackedVector3Array, index: int) -> Vector3:
	if closed:
		return anchors[posmod(index, anchors.size())]
	if index < 0:
		return 2.0 * anchors[0] - anchors[1]
	if index >= anchors.size():
		return 2.0 * anchors[-1] - anchors[-2]
	return anchors[index]
