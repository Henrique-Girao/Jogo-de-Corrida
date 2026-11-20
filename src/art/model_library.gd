extends RefCounted
## Cache only the mesh resources for rigid assets. Skinned characters keep their imported scenes.

const DISTRICT_ASSETS := "res://assets/models/props/distritos.glb"

static var _meshes: Dictionary = {}
static var _district_models: Dictionary = {}


static func meshes(path: String) -> Dictionary:
	if _meshes.has(path):
		return _meshes[path]
	var scene := ResourceLoader.load(path, "PackedScene") as PackedScene
	assert(scene != null, "Modelo importado ausente: " + path)
	var root := scene.instantiate()
	var result: Dictionary = {}
	_collect(root, result)
	root.free()
	_meshes[path] = result
	return result


static func _collect(node: Node, result: Dictionary) -> void:
	if node is MeshInstance3D:
		result[String(node.name)] = node.mesh
	for child in node.get_children():
		_collect(child, result)


static func prop(id: String) -> Mesh:
	if _district_models.is_empty():
		_district_models = meshes(DISTRICT_ASSETS)
		for mesh: Mesh in _district_models.values():
			for i in mesh.get_surface_count():
				var surface := mesh.surface_get_material(i) as StandardMaterial3D
				surface.vertex_color_use_as_albedo = surface.resource_name.begins_with("Pintura")
				if surface.resource_name.begins_with("Difusor"):
					surface.emission_enabled = true
					surface.emission = Color("#ffdea3")
					surface.emission_energy_multiplier = 0.43
	return _district_models[id]
