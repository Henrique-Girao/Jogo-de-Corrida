extends Node3D
## Shared rig with separately authored silhouettes, outfits and hair for the district cast.

const Forms = preload("res://src/art/mesh_forms.gd")
const Style = preload("res://src/art/scene_style.gd")
const WARDROBE := [
	# Lia, Beto, Nia, Cida, Gael, Íris, Toni, Maya, Raul, Lara, Dante and Sol.
	{ "coat": "#a14b3d", "shirt": "#e6c5a3", "pants": "#4a5053", "skin": "#bf805d", "hair": "#412e24", "cut": "bob", "height": 0.96, "width": 0.94 },
	{ "coat": "#3c6f69", "shirt": "#a4c2ae", "pants": "#424e4a", "skin": "#99674b", "hair": "#28292a", "cut": "cap", "height": 1.01, "width": 1.10 },
	{ "coat": "#b48a50", "shirt": "#eed1a0", "pants": "#333d42", "skin": "#d3a080", "hair": "#4c3428", "cut": "bun", "height": 0.95, "width": 0.89 },
	{ "coat": "#576885", "shirt": "#c4ced0", "pants": "#414755", "skin": "#a97054", "hair": "#373941", "cut": "bob", "height": 0.97, "width": 0.99 },
	{ "coat": "#795b6c", "shirt": "#c6a0a4", "pants": "#45404a", "skin": "#754f40", "hair": "#352c29", "cut": "crop", "height": 1.06, "width": 0.94 },
	{ "coat": "#355d51", "shirt": "#a8bda5", "pants": "#394843", "skin": "#d8a788", "hair": "#573a2a", "cut": "bun", "height": 0.98, "width": 1.00 },
	{ "coat": "#9b6345", "shirt": "#d7a675", "pants": "#4c4844", "skin": "#bb855d", "hair": "#48362a", "cut": "cap", "height": 1.06, "width": 1.15 },
	{ "coat": "#646086", "shirt": "#c1a8c1", "pants": "#3e424a", "skin": "#98694a", "hair": "#29252e", "cut": "long", "height": 0.98, "width": 0.93 },
	{ "coat": "#81715a", "shirt": "#dbc79e", "pants": "#474a3d", "skin": "#d5a383", "hair": "#a09b90", "cut": "crop", "height": 1.02, "width": 1.12 },
	{ "coat": "#98666a", "shirt": "#dbb0a4", "pants": "#51464a", "skin": "#875946", "hair": "#3b2b2e", "cut": "bun", "height": 1.03, "width": 0.91 },
	{ "coat": "#3d5366", "shirt": "#a3b5b7", "pants": "#39474d", "skin": "#795544", "hair": "#322722", "cut": "crop", "height": 1.07, "width": 1.06 },
	{ "coat": "#827449", "shirt": "#dad0a5", "pants": "#3f4940", "skin": "#dbae85", "hair": "#745a3c", "cut": "long", "height": 0.98, "width": 0.90 },
]
const DRIVER := { "coat": "#e6d9b7", "shirt": "#aebc63", "pants": "#33434b", "skin": "#bd855e", "hair": "#342a25", "cut": "cap", "height": 1.0, "width": 1.0 }
const SOLE := Color("#957e63")
const GRAPHITE := Color("#273236")

static var _parts: Dictionary = {}
static var _materials: Dictionary = {}

var _body: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _soles: Array[MeshInstance3D] = []
var _phase := 0.0
var _amount := 0.0
var _seed := 0.0


func build(index: int, player := false) -> void:
	var outfit: Dictionary = DRIVER if player else WARDROBE[posmod(index, WARDROBE.size())]
	var coat := Color(outfit.coat)
	var shirt := Color(outfit.shirt)
	var pants := Color(outfit.pants)
	var skin := Color(outfit.skin)
	var hair := Color(outfit.hair)
	var shadow := Style.shadow(0.99, 0.86, 0.48)
	shadow.position.y = 0.021
	add_child(shadow)

	_seed = float(index) * 1.86
	_body = _joint(self, Vector3.ZERO)
	_body.scale = Vector3(float(outfit.width), float(outfit.height), 1.0)
	_form(_body, "jacket", [
		Vector4(0.145, 0.92, 0.095, 0.01), Vector4(0.158, 0.99, 0.112, 0.012),
		Vector4(0.177, 1.26, 0.129, 0.008), Vector4(0.218, 1.375, 0.126, 0.004),
		Vector4(0.177, 1.425, 0.107, 0.008), Vector4(0.080, 1.444, 0.067, 0.008),
	], coat)
	_form(_body, "hips", [
		Vector4(0.152, 0.815, 0.106, 0.01), Vector4(0.177, 0.88, 0.108, 0.008),
		Vector4(0.151, 0.98, 0.095, 0.01),
	], pants)
	_cabinet(_body, Vector3(0, 1.270, -0.118), Vector3(0.087, 0.235, 0.027), shirt)
	_cabinet(_body, Vector3(0, 1.424, 0.005), Vector3(0.159, 0.065, 0.146), coat.darkened(0.20))
	var badge := _cabinet(_body, Vector3(0.096, 1.244, -0.115), Vector3(0.070, 0.026, 0.020), shirt.lightened(0.21))
	badge.rotation.z = -0.10
	if player:
		_cabinet(_body, Vector3(0, 1.238, 0.132), Vector3(0.253, 0.121, 0.017), GRAPHITE)
		for x in [-0.075, 0.0, 0.075]:
			var stripe := _cabinet(_body, Vector3(x, 1.238, 0.144), Vector3(0.034, 0.087, 0.009), shirt)
			stripe.rotation.z = -0.27
	_form(_body, "neck", [Vector4(0.064, 1.429, 0.063, 0.005), Vector4(0.057, 1.545, 0.057, 0.003)], skin)
	_head = _joint(_body, Vector3(0, 1.53, 0))
	_build_head(skin, hair, pants, str(outfit.cut))
	for side: float in [-1.0, 1.0]:
		_build_limbs(side, coat, pants, skin)


func _build_head(skin: Color, hair: Color, cap: Color, cut: String) -> void:
	_form(_head, "head", [
		Vector4(0.063, -0.012, 0.077, -0.016), Vector4(0.093, 0.016, 0.097, -0.006),
		Vector4(0.116, 0.084, 0.108, 0.0), Vector4(0.114, 0.156, 0.106, 0.007),
		Vector4(0.079, 0.198, 0.081, 0.010),
	], skin)
	_cabinet(_head, Vector3(0, 0.064, -0.104), Vector3(0.046, 0.057, 0.028), skin.darkened(0.05))
	_cabinet(_head, Vector3(0, 0.018, -0.095), Vector3(0.057, 0.009, 0.010), skin.darkened(0.33))
	for side: float in [-1.0, 1.0]:
		var eye := _cabinet(_head, Vector3(side * 0.051, 0.104, -0.096), Vector3(0.038, 0.014, 0.009), hair.darkened(0.28))
		eye.rotation.y = -side * 0.28
		_cabinet(_head, Vector3(side * 0.111, 0.060, 0.009), Vector3(0.035, 0.061, 0.044), skin)
	_form(_head, "hair", [
		Vector4(0.115, 0.144, 0.105, 0.009), Vector4(0.119, 0.181, 0.112, 0.010),
		Vector4(0.090, 0.217, 0.092, 0.017), Vector4(0.043, 0.229, 0.055, 0.020),
	], hair)
	match cut:
		"cap":
			_form(_head, "cap", [
				Vector4(0.128, 0.148, 0.115, 0.007), Vector4(0.129, 0.192, 0.115, 0.007),
				Vector4(0.104, 0.230, 0.088, 0.009), Vector4(0.062, 0.240, 0.062, 0.009),
			], cap.darkened(0.16))
			_cabinet(_head, Vector3(0, 0.155, -0.141), Vector3(0.220, 0.024, 0.147), cap.darkened(0.24))
		"bob", "long":
			var tail_y := 0.005 if cut == "long" else 0.058
			_cabinet(_head, Vector3(0, tail_y, 0.092), Vector3(0.234, 0.231, 0.087), hair)
			for side: float in [-1.0, 1.0]:
				var lock := _cabinet(_head, Vector3(side * 0.106, tail_y + 0.017, 0.030), Vector3(0.050, 0.176, 0.105), hair)
				lock.rotation.z = side * -0.08
		"bun":
			_cabinet(_head, Vector3(0.035, 0.175, 0.097), Vector3(0.127, 0.145, 0.140), hair)
		"crop":
			_cabinet(_head, Vector3(0, 0.116, 0.086), Vector3(0.208, 0.118, 0.055), hair)


func _build_limbs(side: float, coat: Color, pants: Color, skin: Color) -> void:
	var arm := _joint(_body, Vector3(side * 0.21, 1.363, 0.008))
	arm.rotation.z = side * 0.13
	_arms.append(arm)
	_form(arm, "sleeve", [
		Vector4(0.059, -0.326, 0.064, -0.008), Vector4(0.069, -0.218, 0.078, 0.0),
		Vector4(0.080, -0.061, 0.090, 0.007), Vector4(0.057, 0.044, 0.072, 0.008),
	], coat.darkened(0.065))
	_cabinet(arm, Vector3(0, -0.328, -0.006), Vector3(0.118, 0.049, 0.129), coat.darkened(0.22))
	_form(arm, "hand", [
		Vector4(0.032, -0.419, 0.037, -0.023), Vector4(0.050, -0.383, 0.050, -0.018),
		Vector4(0.042, -0.325, 0.043, -0.012),
	], skin)
	var leg := _joint(_body, Vector3(side * 0.097, 0.86, 0.008))
	_legs.append(leg)
	_form(leg, "thigh", [
		Vector4(0.073, -0.453, 0.072, -0.001), Vector4(0.087, -0.29, 0.085, 0.002),
		Vector4(0.099, -0.053, 0.098, 0.002), Vector4(0.089, 0.047, 0.087, 0.008),
	], pants)
	var knee := _joint(leg, Vector3(0, -0.419, -0.002))
	_knees.append(knee)
	_form(knee, "calf", [
		Vector4(0.054, -0.357, 0.057, 0.0), Vector4(0.066, -0.219, 0.071, 0.010),
		Vector4(0.077, -0.086, 0.076, 0.002), Vector4(0.072, 0.014, 0.073, 0.0),
	], pants.darkened(0.07))
	_form(knee, "boot", [
		Vector4(0.082, -0.423, 0.128, -0.057), Vector4(0.083, -0.380, 0.126, -0.058),
		Vector4(0.070, -0.348, 0.098, -0.044), Vector4(0.055, -0.315, 0.058, 0.0),
	], GRAPHITE)
	_soles.append(_cabinet(knee, Vector3(0, -0.423, -0.056), Vector3(0.159, 0.029, 0.238), SOLE))


func animate(delta: float, speed: float) -> void:
	_amount = move_toward(_amount, clampf(speed / 3.6, 0.0, 1.0), delta * 8.0)
	_phase += delta * (2.1 + speed * 2.05)
	var stride := sin(_phase) * _amount
	_legs[0].rotation.x = stride * 0.61
	_legs[1].rotation.x = -stride * 0.61
	_knees[0].rotation.x = maxf(0, -stride) * 0.66
	_knees[1].rotation.x = maxf(0, stride) * 0.66
	_arms[0].rotation.x = -stride * 0.43 + sin(_phase + _seed) * 0.042
	_arms[1].rotation.x = stride * 0.43 + sin(_phase - _seed) * 0.042
	_head.rotation.y = sin(_phase * 0.51 + _seed) * 0.21 * (1.0 - _amount)
	_body.rotation.z = sin(_phase) * _amount * 0.024
	_body.position.y = 0.0
	# Anchor the lower sole after posing the knees, including the heel and toe on a stride.
	_body.position.y = 0.002 - minf(_sole_height(0), _sole_height(1))


func _sole_height(index: int) -> float:
	var foot := _body.transform * _legs[index].transform * _knees[index].transform * _soles[index].transform
	var half_height := (absf(foot.basis.x.y) + absf(foot.basis.y.y) + absf(foot.basis.z.y)) * 0.5
	return foot.origin.y - half_height


static func _joint(parent: Node3D, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	return pivot


static func _form(parent: Node3D, key: String, rings: Array[Vector4], tint: Color) -> void:
	if not _parts.has(key):
		_parts[key] = Forms.loft(rings, 8, PI * 0.125)
	_piece(parent, _parts[key], tint)


static func _cabinet(parent: Node3D, at: Vector3, dimensions: Vector3, tint: Color) -> MeshInstance3D:
	var piece := _piece(parent, Forms.cabinet(), tint)
	piece.position = at
	piece.scale = dimensions
	return piece


static func _piece(parent: Node3D, mesh: Mesh, tint: Color) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.visibility_range_end = 38.0
	if not _materials.has(tint):
		var paint := StandardMaterial3D.new()
		paint.albedo_color = tint
		paint.roughness = 0.82
		_materials[tint] = paint
	piece.material_override = _materials[tint]
	parent.add_child(piece)
	return piece
