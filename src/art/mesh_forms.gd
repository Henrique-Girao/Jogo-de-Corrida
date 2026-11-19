extends RefCounted
## Tapered rings for deliberately faceted fabrics, architecture and foliage.
## Each ring specifies a half-width, height, half-depth and depth offset.

static var _beveled: ArrayMesh


static func loft(rings: Array[Vector4], sides: int = 8, offset: float = 0.0, squared := false) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(rings.size() - 1):
		for side in sides:
			var angle := TAU * float(side) / float(sides) + offset
			var next := TAU * float(side + 1) / float(sides) + offset
			var normal := Vector3(cos((angle + next) * 0.5), 0, sin((angle + next) * 0.5))
			var a := _point(rings[level], angle, squared)
			var b := _point(rings[level], next, squared)
			var c := _point(rings[level + 1], next, squared)
			var d := _point(rings[level + 1], angle, squared)
			_face(surface, a, b, c, normal)
			_face(surface, a, c, d, normal)
	for end in [0, rings.size() - 1]:
		var ring: Vector4 = rings[end]
		var axis := Vector3.DOWN if end == 0 else Vector3.UP
		var center := Vector3(0, ring.y, ring.w)
		for side in sides:
			var angle := TAU * float(side) / float(sides) + offset
			var next := TAU * float(side + 1) / float(sides) + offset
			_face(surface, center, _point(ring, angle, squared), _point(ring, next, squared), axis)
	surface.index()
	return surface.commit()


static func cabinet() -> ArrayMesh:
	if _beveled == null:
		_beveled = loft([
			Vector4(0.46, -0.5, 0.46, 0), Vector4(0.50, -0.455, 0.50, 0),
			Vector4(0.50, 0.435, 0.50, 0), Vector4(0.44, 0.5, 0.44, 0),
		], 8, PI * 0.125, true)
	return _beveled


static func _point(ring: Vector4, angle: float, squared: bool) -> Vector3:
	var profile := Vector2.from_angle(angle)
	if squared:
		profile = Vector2(
			signf(profile.x) * (1.0 if absf(profile.x) > 0.7 else 0.83),
			signf(profile.y) * (1.0 if absf(profile.y) > 0.7 else 0.83))
	return Vector3(ring.x * profile.x, ring.y, ring.z * profile.y + ring.w)


static func _face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.length_squared() < 0.25:
		return
	var front := normal.dot(outward) > 0.0
	for point: Vector3 in ([a, c, b] if front else [a, b, c]):
		surface.set_normal(normal if front else -normal)
		surface.add_vertex(point)
