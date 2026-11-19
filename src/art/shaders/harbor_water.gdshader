shader_type spatial;
render_mode unshaded, fog_disabled;

uniform vec4 deep : source_color = vec4(0.09, 0.17, 0.24, 1.0);
uniform vec4 reflected : source_color = vec4(0.32, 0.49, 0.55, 1.0);
uniform vec4 mist : source_color = vec4(0.58, 0.55, 0.61, 1.0);
uniform float mist_depth = 145.0;
varying vec3 world_spot;

void vertex() {
	world_spot = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 position = world_spot.xz;
	float wave = sin(position.y * 2.1 + position.x * 0.28 - TIME * 0.68 + sin(position.x * 0.38 + TIME * 0.33) * 0.83);
	float crest = smoothstep(0.72, 0.99, wave);
	float drift = 0.5 + sin(position.x * 0.44 + position.y * 0.37 + TIME * 0.29) * 0.5;
	float distance_fade = 1.0 - smoothstep(55.0, 185.0, length(VERTEX));
	float angle = pow(1.0 - abs(dot(normalize(NORMAL), VIEW)), 2.1);
	vec3 water = mix(deep.rgb, reflected.rgb, 0.14 + 0.37 * angle + crest * drift * 0.21 * distance_fade);
	float haze = smoothstep(mist_depth * 0.46, mist_depth, -VERTEX.z);
	ALBEDO = mix(water, mist.rgb, haze);
}
