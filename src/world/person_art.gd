extends Node3D
## Imported costumes and skins share the same walking pose and floor contacts.

const Style = preload("res://src/art/scene_style.gd")
const CAST := ["lia", "beto", "nia", "cida", "gael", "iris", "toni", "maya", "raul", "lara", "dante", "sol"]
const LEFT := 0
const RIGHT := 1

var _visual: Node3D
var _rig: Skeleton3D
var _hips: int
var _head: int
var _arms: Array[int] = []
var _elbows: Array[int] = []
var _legs: Array[int] = []
var _knees: Array[int] = []
var _feet: Array[int] = []
var _rest_rotation: Dictionary[int, Quaternion] = {}
var _pose_axis: Dictionary[int, Vector3] = {}
var _contacts: Array[PackedVector3Array] = []
var _phase := 0.0
var _amount := 0.0
var _seed := 0.0


func build(index: int, player := false) -> void:
	var id: String = "piloto" if player else CAST[posmod(index, CAST.size())]
	var scene := load("res://assets/models/people/%s.glb" % id) as PackedScene
	_visual = scene.instantiate() as Node3D
	add_child(_visual)
	_rig = _visual.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_hips = _register("Corpo", Vector3.BACK)
	_head = _register("Cabeca", Vector3.UP)
	for suffix in [".L", ".R"]:
		_arms.append(_register("Ombro" + suffix, Vector3.RIGHT))
		_elbows.append(_register("Cotovelo" + suffix, Vector3.RIGHT))
		_legs.append(_register("Coxa" + suffix, Vector3.RIGHT))
		_knees.append(_register("Joelho" + suffix, Vector3.RIGHT))
		_feet.append(_register("Pe" + suffix, Vector3.RIGHT))
	_read_floor_contacts()
	_seed = float(index) * 1.86
	var shadow := Style.shadow(0.99, 0.86, 0.48)
	shadow.position.y = 0.021
	add_child(shadow)
	animate(0.0, 0.0)


func _register(label: String, rest_axis: Vector3) -> int:
	var bone := _rig.find_bone(label)
	assert(bone >= 0, "Osso ausente: " + label)
	_rest_rotation[bone] = _rig.get_bone_rest(bone).basis.get_rotation_quaternion()
	_pose_axis[bone] = (_rig.get_bone_global_rest(bone).basis.inverse() * rest_axis).normalized()
	return bone


func _read_floor_contacts() -> void:
	var geometry := _visual.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arrays := geometry.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var influences := roundi(float(joints.size()) / positions.size())
	for foot in _feet:
		var inverse := _rig.get_bone_global_rest(foot).affine_inverse()
		var sole := PackedVector3Array()
		var foot_name := _rig.get_bone_name(foot)
		for i in positions.size():
			if positions[i].y > 0.007:
				continue
			var bind := joints[int(i * influences)]
			if geometry.skin.get_bind_name(bind) == foot_name:
				var point := inverse * positions[i]
				if not sole.has(point):
					sole.append(point)
		assert(not sole.is_empty(), "Contato dos pés ausente: " + String(foot_name))
		_contacts.append(sole)

func _pose(bone: int, angle: float) -> void:
	_rig.set_bone_pose_rotation(bone, _rest_rotation[bone] * Quaternion(_pose_axis[bone], angle))


func animate(delta: float, speed: float) -> void:
	_amount = move_toward(_amount, clampf(speed / 3.6, 0.0, 1.0), delta * 8.0)
	_phase += delta * (2.1 + speed * 2.05)
	var stride := sin(_phase) * _amount
	_pose(_hips, stride * 0.021)
	_pose(_head, sin(_phase * 0.51 + _seed) * 0.20 * (1.0 - _amount))
	_pose(_legs[LEFT], stride * 0.61)
	_pose(_legs[RIGHT], -stride * 0.61)
	_pose(_knees[LEFT], maxf(0.0, -stride) * 0.67)
	_pose(_knees[RIGHT], maxf(0.0, stride) * 0.67)
	_pose(_feet[LEFT], -stride * 0.25)
	_pose(_feet[RIGHT], stride * 0.25)
	_pose(_arms[LEFT], -stride * 0.43 + sin(_phase + _seed) * 0.042)
	_pose(_arms[RIGHT], stride * 0.43 + sin(_phase - _seed) * 0.042)
	_pose(_elbows[LEFT], -_amount * (0.17 + maxf(stride, 0.0) * 0.3))
	_pose(_elbows[RIGHT], -_amount * (0.17 + maxf(-stride, 0.0) * 0.3))

	# Stabilize the lowest of the posed heel and toe contacts on the floor.
	var lowest := INF
	for i in _feet.size():
		var pose := _rig.get_bone_global_pose(_feet[i])
		for contact in _contacts[i]:
			lowest = minf(lowest, (pose * contact).y)
	_visual.position.y = 0.002 - lowest
