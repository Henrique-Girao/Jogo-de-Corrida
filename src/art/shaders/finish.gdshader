shader_type spatial;
render_mode diffuse_burley;

uniform vec4 tint : source_color = vec4(0.65, 0.12, 0.08, 1.0);
uniform float coat_roughness : hint_range(0.05, 1.0) = 0.32;
uniform float sheen : hint_range(0.0, 1.0) = 0.52;
uniform sampler2D panel_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float glass : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 normal = normalize(NORMAL);
	vec3 world_reflection = mat3(INV_VIEW_MATRIX) * reflect(-normalize(VIEW), normal);
	float sky_fill = smoothstep(-0.14, 0.62, world_reflection.y);
	float horizon = exp(-abs(world_reflection.y - 0.22) * 5.6);
	float rim = pow(1.0 - clamp(dot(normal, VIEW), 0.0, 1.0), 3.1);
	vec3 tint_variance = mix(vec3(0.77, 0.83, 0.90), vec3(1.06, 1.04, 1.0), sky_fill);
	vec3 clearcoat = mix(vec3(0.13, 0.27, 0.41), vec3(0.79, 0.88, 0.95), sky_fill);
	vec3 glazing = mix(vec3(0.017, 0.034, 0.054), vec3(0.105, 0.180, 0.228), sky_fill);
	vec3 baked = texture(panel_map, UV).rgb;
	vec3 foundation = mix(tint.rgb * baked, glazing * 0.75 + baked * 0.33, glass);
	ALBEDO = foundation * tint_variance;
	METALLIC = mix(0.16, 0.10, glass);
	ROUGHNESS = coat_roughness;
	SPECULAR = mix(0.46, 0.24, glass);
	EMISSION = clearcoat * sheen * (0.024 * sky_fill + 0.055 * rim + 0.043 * horizon)
		+ foundation * (0.064 + 0.055 * sky_fill + 0.12 * glass * sky_fill);
}
