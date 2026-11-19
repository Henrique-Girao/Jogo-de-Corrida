extends Node3D
## Jointed low-poly avatar shared by the player and people around Baía do Sal.

const Geometry = preload("res://src/world/sector_geometry.gd")
const PALETTES: Array[Color] = [
	Color("#8c4133"), Color("#567e7b"), Color("#b49a53"), Color("#607b9c"),
	Color("#76516d"), Color("#305551"), Color("#b46642"), Color("#5c688d"),
	Color("#8a765d"), Color("#966362"), Color("#465668"), Color("#8e7958"),
]
const SKINS: Array[Color] = [
	Color("#c38661"), Color("#916049"), Color("#dba480"), Color("#a66b4b"),
	Color("#704837"), Color("#dfb28e"),
]

static var _box := BoxMesh.new()
static var _materials: Dictionary = {}

var _body: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _phase := 0.0
var _amount := 0.0
var _seed := 0.0


func build(index: int, player := false) -> void:
	var coat := Color("#e8dbb5") if player else PALETTES[posmod(index, PALETTES.size())]
	var accent := Color("#dafa5e") if player else coat.lightened(0.29)
	var skin := SKINS[posmod(index + 2, SKINS.size())]
	var denim := Color("#29373c").lerp(coat, 0.14)
	var shadow := Geometry.shadow(1.28, 1.10)
	shadow.position.y = 0.021
	add_child(shadow)

	_seed = float(index) * 1.86
	_body = _joint(self, Vector3.ZERO)
	_piece(_body, Vector3(0, 1.17, 0.015), Vector3(0.40, 0.47, 0.23), coat)
	_piece(_body, Vector3(0, 0.91, 0), Vector3(0.33, 0.16, 0.22), denim)
	_piece(_body, Vector3(0, 1.00, 0.128), Vector3(0.31, 0.035, 0.02), coat.darkened(0.31))
	_piece(_body, Vector3(0, 1.27, 0.137), Vector3(0.28, 0.054, 0.022), accent)
	_piece(_body, Vector3(0, 1.49, 0.002), Vector3(0.13, 0.14, 0.12), skin)
	var badge := _piece(_body, Vector3(0.074, 1.23, -0.124), Vector3(0.11, 0.058, 0.03), accent)
	badge.rotation.z = -0.08
	if player:
		for x in [-0.09, 0.0, 0.09]:
			var slash := _piece(_body, Vector3(x, 1.205, 0.139), Vector3(0.042, 0.115, 0.013), Color("#344044"))
			slash.rotation.z = -0.29

	_head = _joint(_body, Vector3(0, 1.56, 0))
	_piece(_head, Vector3(0, 0.056, 0), Vector3(0.245, 0.252, 0.219), skin)
	var hair := Color("#271e20").lerp(denim, 0.34)
	_piece(_head, Vector3(0, 0.168, 0.005), Vector3(0.256, 0.09, 0.232), hair)
	_piece(_head, Vector3(0, 0.064, 0.099), Vector3(0.25, 0.136, 0.044), hair)
	_piece(_head, Vector3(0, 0.064, -0.122), Vector3(0.058, 0.044, 0.03), skin.darkened(0.14))
	for side in [-1.0, 1.0]:
		_piece(_head, Vector3(side * 0.069, 0.104, -0.117), Vector3(0.046, 0.025, 0.022), hair)
		_piece(_head, Vector3(side * 0.128, 0.054, -0.003), Vector3(0.036, 0.063, 0.043), skin)
	if player or index % 3 == 0 or index % 3 == 1:
		_piece(_head, Vector3(0, 0.186, -0.010), Vector3(0.272, 0.069, 0.237), denim.darkened(0.2))
		if player or index % 3 == 0:
			_piece(_head, Vector3(0, 0.153, -0.15), Vector3(0.232, 0.029, 0.123), denim.darkened(0.2))

	for side in [-1.0, 1.0]:
		var arm := _joint(_body, Vector3(side * 0.243, 1.36, 0))
		arm.rotation.z = side * 0.13
		_arms.append(arm)
		_piece(arm, Vector3(side * 0.005, -0.145, 0), Vector3(0.151, 0.35, 0.175), coat.darkened(0.09))
		_piece(arm, Vector3(0, -0.321, -0.015), Vector3(0.132, 0.108, 0.15), skin)
		var leg := _joint(_body, Vector3(side * 0.103, 0.84, 0))
		_legs.append(leg)
		_piece(leg, Vector3(0, -0.333, 0), Vector3(0.174, 0.685, 0.183), denim)
		_piece(leg, Vector3(0, -0.75, -0.05), Vector3(0.186, 0.157, 0.277), Color("#27313b"))
		_piece(leg, Vector3(0, -0.811, -0.057), Vector3(0.192, 0.034, 0.281), Color("#9a9b8c"))


func animate(delta: float, speed: float) -> void:
	_amount = move_toward(_amount, clampf(speed / 3.6, 0.0, 1.0), delta * 8.0)
	_phase += delta * (2.25 + speed * 2.05)
	var stride := sin(_phase) * _amount
	_legs[0].rotation.x = stride * 0.69
	_legs[1].rotation.x = -stride * 0.69
	_arms[0].rotation.x = -stride * 0.46 + sin(_phase + _seed) * 0.065
	_arms[1].rotation.x = stride * 0.46 + sin(_phase - _seed) * 0.065
	_head.rotation.y = sin(_phase * 0.51 + _seed) * 0.24 * (1.0 - _amount)
	_body.position.y = (0.009 + absf(stride) * 0.046) + sin(_phase + _seed) * 0.009


static func _joint(parent: Node3D, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	return pivot


static func _piece(parent: Node3D, at: Vector3, dimensions: Vector3, tint: Color) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = _box
	piece.scale = dimensions
	piece.position = at
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.visibility_range_end = 38.0
	if not _materials.has(tint):
		var paint := StandardMaterial3D.new()
		paint.albedo_color = tint
		paint.roughness = 0.83
		_materials[tint] = paint
	piece.material_override = _materials[tint]
	parent.add_child(piece)
	return piece
