shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 glow_color : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float glow_energy : hint_range(0.0, 3.0) = 0.0;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;

void fragment() {
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), fresnel_power);
	ALBEDO = glow_color.rgb;
	ALPHA = fresnel * glow_energy * glow_color.a;
}
