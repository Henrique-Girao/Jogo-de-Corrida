extends RefCounted
## Shared materials and light response. Palettes remain authored for each location.

const SKY_SHADER = preload("res://src/art/shaders/horizon.gdshader")
const WATER_SHADER = preload("res://src/art/shaders/harbor_water.gdshader")

static var _textures: Dictionary = {}
static var _occlusion_textures: Dictionary = {}
static var _cloud_texture: ImageTexture
static var _sky_plane: QuadMesh


static func sky(top: Color, rim: Color, land: Color, sunlight: Color, heading: Vector3, clouds: float) -> MeshInstance3D:
	if _cloud_texture == null:
		var density := FastNoiseLite.new()
		density.seed = 27908
		density.frequency = 0.026
		density.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		density.fractal_octaves = 4
		density.fractal_gain = 0.44
		var cloud_map := density.get_seamless_image(256, 256)
		cloud_map.generate_mipmaps()
		_cloud_texture = ImageTexture.create_from_image(cloud_map)
		_sky_plane = QuadMesh.new()
		_sky_plane.size = Vector2(2, 2)
	var dome := ShaderMaterial.new()
	dome.shader = SKY_SHADER
	dome.set_shader_parameter("zenith", top)
	dome.set_shader_parameter("horizon", rim)
	dome.set_shader_parameter("ground", land)
	dome.set_shader_parameter("sunset", sunlight)
	dome.set_shader_parameter("light_heading", heading.normalized())
	dome.set_shader_parameter("cloud", rim.lerp(Color("#f3f0e2"), 0.65))
	dome.set_shader_parameter("cloud_density", clouds)
	dome.set_shader_parameter("cloud_map", _cloud_texture)
	dome.render_priority = Material.RENDER_PRIORITY_MIN
	var backdrop := MeshInstance3D.new()
	backdrop.name = "Céu"
	backdrop.mesh = _sky_plane
	backdrop.material_override = dome
	# The vertex shader fills the viewport at the far clip plane.
	backdrop.custom_aabb = AABB(Vector3(-1600, -1600, -1600), Vector3(3200, 3200, 3200))
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return backdrop


static func water(size: Vector2, deep: Color, highlight: Color, mist: Color, mist_depth: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("deep", deep)
	material.set_shader_parameter("reflected", highlight)
	material.set_shader_parameter("mist", mist)
	material.set_shader_parameter("mist_depth", mist_depth)
	var surface := MeshInstance3D.new()
	surface.name = "Água"
	surface.mesh = plane
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return surface


static func pavement(finish: String) -> Texture2D:
	if _textures.has(finish):
		return _textures[finish]
	const SIDE := 128
	var image := Image.create_empty(SIDE, SIDE, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 186 + finish.length() * 71
	noise.frequency = 0.075
	var random := RandomNumberGenerator.new()
	random.seed = 218 + finish.length()
	for y in SIDE:
		for x in SIDE:
			var fine := random.randf()
			var patch := noise.get_noise_2d(float(x), float(y))
			var shade: float
			match finish:
				"asphalt":
					var aggregate := 0.022 * smoothstep(0.88, 0.99, fine)
					shade = 0.906 + patch * 0.079 + (fine - 0.5) * 0.081 + aggregate
				"slab":
					var join := float(mini(mini(x, y), mini(SIDE - x, SIDE - y)) < 2)
					shade = 0.954 + patch * 0.072 + (fine - 0.5) * 0.045 - join * 0.102
				"earth":
					shade = 0.897 + patch * 0.148 + (fine - 0.5) * 0.060
				_:
					shade = 0.954 + patch * 0.09 + (fine - 0.5) * 0.052
			image.set_pixel(x, y, Color(shade, shade, shade))
	image.generate_mipmaps()
	var material_texture := ImageTexture.create_from_image(image)
	_textures[finish] = material_texture
	return material_texture


static func shadow(width: float, length: float, opacity: float = 0.53, squared: bool = false) -> MeshInstance3D:
	if not _occlusion_textures.has(squared):
		const SIDE := 56
		var image := Image.create_empty(SIDE, SIDE, false, Image.FORMAT_RGBA8)
		for y in SIDE:
			for x in SIDE:
				var at := (Vector2(x, y) / float(SIDE - 1) - Vector2.ONE * 0.5) * 2.0
				var radius := pow(pow(absf(at.x), 4.0) + pow(absf(at.y), 4.0), 0.25) if squared else at.length()
				var alpha := 1.0 - smoothstep(0.44 if squared else 0.24, 1.0, radius)
				image.set_pixel(x, y, Color(0.047, 0.068, 0.085, alpha))
		_occlusion_textures[squared] = ImageTexture.create_from_image(image)
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = _occlusion_textures[squared]
	paint.albedo_color = Color(1, 1, 1, opacity)
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.texture_repeat = false
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, length)
	var instance := MeshInstance3D.new()
	instance.name = "Sombra de contato"
	instance.mesh = plane
	instance.material_override = paint
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
