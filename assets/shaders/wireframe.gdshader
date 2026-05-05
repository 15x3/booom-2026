shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform vec4 line_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float line_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float fresnel_power : hint_range(1.0, 8.0) = 3.0;
uniform float scan_speed : hint_range(0.0, 10.0) = 1.0;
uniform float scan_intensity : hint_range(0.0, 1.0) = 0.15;

void vertex() {
	VERTEX += NORMAL * 0.001;
}

void fragment() {
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	edge = pow(edge, fresnel_power);
	float scan = sin((UV.y + UV.x) * 40.0 + TIME * scan_speed) * 0.5 + 0.5;
	scan = scan * scan_intensity;
	ALBEDO = line_color.rgb;
	ALPHA = edge * line_opacity + scan;
}
