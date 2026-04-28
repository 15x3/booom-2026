shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float strength : hint_range(0.0, 1.5) = 0.0;
uniform float time = 0.0;
uniform float blackout : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5, 0.5);
	vec2 delta = uv - center;
	float dist = length(delta);

	float barrel = 1.0 + strength * dist * dist * 3.0;
	vec2 lens_uv = center + delta / barrel;

	float turbulence = strength * 0.006;
	lens_uv.x += sin(dist * 20.0 - time * 3.0) * turbulence;
	lens_uv.y += cos(dist * 18.0 + time * 2.5) * turbulence;

	lens_uv = clamp(lens_uv, vec2(0.0), vec2(1.0));

	float ca = strength * 0.004;
	vec2 ca_offset = vec2(ca, ca * 0.7);
	float r = texture(SCREEN_TEXTURE, lens_uv + ca_offset).r;
	float g = texture(SCREEN_TEXTURE, lens_uv).g;
	float b = texture(SCREEN_TEXTURE, lens_uv - ca_offset).b;

	float vignette = 1.0 - smoothstep(0.3, 0.7, dist) * strength * 0.5;

	float active = step(0.01, strength);
	vec3 distorted = vec3(r, g, b) * vignette;
	vec3 original = texture(SCREEN_TEXTURE, uv).rgb;
	vec3 result = mix(original, distorted, active);
	result = mix(result, vec3(0.0), step(0.5, blackout));

	COLOR = vec4(result, 1.0);
}
