shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 zenith : source_color = vec4(0.20, 0.39, 0.54, 1.0);
uniform vec4 horizon : source_color = vec4(0.78, 0.74, 0.65, 1.0);
uniform vec4 ground : source_color = vec4(0.23, 0.30, 0.33, 1.0);
uniform vec4 cloud : source_color = vec4(0.87, 0.85, 0.78, 1.0);
uniform vec4 sunset : source_color = vec4(0.98, 0.72, 0.49, 1.0);
uniform vec3 light_heading = vec3(0.49, 0.22, -0.84);
uniform float cloud_density : hint_range(0.0, 1.0) = 0.28;
uniform sampler2D cloud_map : filter_linear_mipmap, repeat_enable;
varying vec3 sky_ray;

void vertex() {
	vec2 clip = VERTEX.xy;
	vec4 ray_in_view = INV_PROJECTION_MATRIX * vec4(clip, 1.0, 1.0);
	sky_ray = mat3(INV_VIEW_MATRIX) * ray_in_view.xyz;
	POSITION = vec4(clip, CLIP_SPACE_FAR + 0.0000002, 1.0);
}

void fragment() {
	vec3 ray = normalize(sky_ray);
	float elevation = max(ray.y, 0.0);
	vec3 tint = mix(horizon.rgb, zenith.rgb, pow(smoothstep(0.0, 0.78, elevation), 0.55));
	tint = mix(tint, ground.rgb, smoothstep(0.0, 0.33, -ray.y));
	float near_sun = max(0.0, dot(normalize(light_heading), ray));
	tint += sunset.rgb * (0.20 * pow(near_sun, 19.0) + 0.19 * pow(near_sun, 580.0)) * smoothstep(-0.04, 0.02, ray.y);
	if (ray.y > 0.012) {
		vec2 spread = ray.xz / (0.30 + elevation);
		vec2 uv = spread * vec2(0.32, 0.54) + vec2(0.58, 0.29);
		float weather = texture(cloud_map, uv).r;
		float altitude = smoothstep(0.025, 0.14, ray.y) * (1.0 - smoothstep(0.43, 0.81, ray.y));
		float veil = smoothstep(0.51, 0.77, weather) * altitude * cloud_density;
		vec3 reflected_light = mix(cloud.rgb * 0.94, sunset.rgb, 0.22 * pow(near_sun, 5.0));
		tint = mix(tint, reflected_light, veil);
	}
	ALBEDO = tint;
	ALPHA = 1.0;
}
