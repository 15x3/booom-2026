shader_type spatial;

render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec3 inner_color : source_color = vec3(1.0, 0.95, 0.7);
uniform vec3 outer_color : source_color = vec3(1.0, 0.2, 0.02);
uniform float inner_radius : hint_range(0.1, 5.0) = 2.2;
uniform float outer_radius : hint_range(0.1, 8.0) = 4.0;
uniform float intensity : hint_range(0.0, 10.0) = 4.0;

void fragment() {
	float dist = length(VERTEX.xz);
	float t = clamp((dist - inner_radius) / (outer_radius - inner_radius), 0.0, 1.0);

	float edge_fade = smoothstep(0.0, 0.15, t) * smoothstep(1.0, 0.75, t);

	vec3 color = mix(inner_color, outer_color, t);
	EMISSION = color * intensity * edge_fade;
	ALBEDO = vec3(0.0);
	ALPHA = edge_fade;
}
